import Combine

extension Publishers {
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// The publisher only fails if the upstream fails.
    public struct SequentialMap<Upstream,Output>: Publisher where Upstream:Publisher {
        public typealias Failure = Upstream.Failure

        /// The upstream publisher.
        public let upstream: Upstream
        /// The closure generating the downstream value.
        /// - note: The closure is kept in the publisher; thus, if you keep the publisher around any reference in the closure will be kept too.
        public let closure: Async.Closure<Upstream.Output, Output>
        /// Creates a publisher that transforms the incoming value into another value, but may respond at a time in the future.
        /// - parameter upstream: The event emitter to the publisher being created.
        /// - parameter transform: Closure in charge of transforming the values.
        /// - note: The closure is kept in the publisher; thus, if you keep the publisher around any reference in the closure will be kept too.
        public init(upstream: Upstream, transform: @escaping Async.Closure<Upstream.Output,Output>) {
            self.upstream = upstream
            self.closure = transform
        }

        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let conduit = Async.Conduit<Upstream,Self,S,Output>(downstream: subscriber, closure: self.closure)
            self.upstream.subscribe(conduit)
        }
    }
}

// - todo: Merge with SequentialTryMap

extension Async {
    /// Subscription representing an activated `SequentialMap` publisher.
    fileprivate final class Conduit<Upstream,Stage,Downstream,Value>: Subscription, Subscriber where Upstream:Publisher, Stage:Publisher, Downstream:Subscriber, Downstream.Input==Stage.Output, Downstream.Failure==Stage.Failure, Value==Stage.Output, Stage.Failure==Upstream.Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        typealias TransformClosure = Async.Closure<Upstream.Output,Value>
        
        /// Enum listing all possible conduit states.
        @LockableState private var state: State<WaitConfiguration,ActiveConfiguration>
        
        /// Creates a representation of an `SequentialMap` publisher.
        init(downstream: Downstream, closure: @escaping TransformClosure) {
            self._state = .init(wrappedValue: .awaitingSubscription(.init(downstream: downstream, closure: closure)))
        }
        
        deinit {
            self.cancel()
        }
        
        func cancel() {
            guard case .active(let config) = self._state.terminate() else { return }
            config.upstream?.cancel()
        }
        
        func receive(subscription: Subscription) {
            guard let config = self._state.activate(locking: { .init(upstream: subscription, downstream: $0.downstream, closure: $0.closure) }) else {
                return subscription.cancel()
            }
            config.downstream.receive(subscription: self)
        }
        
        func request(_ demand: Subscribers.Demand) {
            precondition(demand >= 0)
            
            self._state.lock()
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            
            config.demand += demand
            guard config.demand > 0, case .idle = config.status  else { return self._state.unlock() }
            
            if let value = config.buffer.popFirst() {
                let closure = config.closure
                let promise = self.makePromise()
                config.status = .processing
                self._state.unlock()
                closure(value, promise)
            } else if let upstream = config.upstream {
                self._state.unlock()
                upstream.request(.max(1))
            } else {
                self.state = .terminated
                self._state.unlock()
                config.downstream.receive(completion: .finished)
            }
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            self._state.lock()
            guard let config = self.state.activeConfiguration else { self._state.unlock(); return .none }
            
            config.buffer.append(input)
            guard case .idle = config.status, config.demand > 0 else { self._state.unlock(); return .none }
            
            let closure = config.closure
            let value = config.buffer.removeFirst()
            let promise = self.makePromise()
            config.status = .processing
            self._state.unlock()
            
            closure(value, promise)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            self._state.lock()
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            
            switch (completion, config.status) {
            case (.failure, _):
                fallthrough
            case (.finished, .idle) where config.buffer.isEmpty:
                self.state = .terminated
                let downstream = config.downstream
                self._state.unlock()
                downstream.receive(completion: completion)
            default:
                config.upstream = nil
                self._state.unlock()
            }
        }
    }
}

extension Async.Conduit {
    /// - precondition: When this function is called `self` is within the lock and in an active state.
    private func makePromise() -> Async.Promise<Value> {
        var isFinished = false
        
        return { [weak self] (result, request) in
            guard let self = self else { return .forbidden }
            
            self._state.lock()
            guard let config = self.state.activeConfiguration, !isFinished else {
                self._state.unlock()
                return .forbidden
            }
            
            assert(config.status == .processing)
            assert(config.demand > 0)
            
            let downstream = config.downstream
            config.demand -= 1
            
            guard case .continue = request else {
                isFinished = true
                config.status = .idle
                self._state.unlock()
                
                self.request(downstream.receive(result))
                return .forbidden
            }
            
            let totalDemand = config.demand
            self._state.unlock()
            
            guard totalDemand == .none else {
                self.request(downstream.receive(result))
                return .allowed
            }
            
            let demand = downstream.receive(result)
            precondition(demand >= 0)
            
            self._state.lock()
            config.demand += demand
            if config.demand > 0 {
                self._state.unlock()
                return .allowed
            } else if config.upstream == nil && config.buffer.isEmpty {
                isFinished = true
                self.state = .terminated
                self._state.unlock()
                config.downstream.receive(completion: .finished)
            } else {
                isFinished = true
                config.status = .idle
                self._state.unlock()
            }
            
            return .forbidden
        }
    }
}

extension Async.Conduit {
    /// Values needed for the subscription awaiting state.
    private struct WaitConfiguration {
        let downstream: Downstream
        let closure: TransformClosure
    }
    
    /// Values needed for the subscription active state.
    private final class ActiveConfiguration {
        /// The subscription used to manage the upstream back-pressure.
        var upstream: Subscription?
        /// The subscriber receiving the input and completion.
        let downstream: Downstream
        /// The closure being called for each upstream value emitted.
        let closure: TransformClosure
        /// Buffer for values received from the upstream.
        var buffer: [Upstream.Output]
        /// The values requested by the downstream.
        var demand: Subscribers.Demand
        /// Boolean indicating whether the `Conduit` is currently transforming a value.
        var status: Status
        /// Designated initializer providing the requried upstream and downstream.
        init(upstream: Subscription, downstream: Downstream, closure: @escaping TransformClosure) {
            self.upstream = upstream
            self.downstream = downstream
            self.closure = closure
            self.buffer = .init()
            self.demand = .none
            self.status = .idle
        }
        
        /// Whether there is a closure being executed.
        enum Status: Equatable {
            /// No closure is being executed.
            case idle
            /// A closure is being executed.
            case processing
        }
    }
}
