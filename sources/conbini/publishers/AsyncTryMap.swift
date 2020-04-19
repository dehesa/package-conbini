import Combine

extension Publishers {
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// This publisher only fails if the upstream fails. Also, remember that asynchronous and a parallel setting different than one may return the values in an unexpected order.
    public struct AsyncTryMap<Upstream,Output>: Publisher where Upstream:Publisher {
        public typealias Failure = Swift.Error
        /// The closure type used to return the result of the transformation.
        /// - parameter result: The transformation result.
        /// - parameter request: Whether the closure want to continue sending values or it is done.
        /// - returns: Enum indicating whether the closure can keep calling this promise.
        public typealias Promise = (_ result: Result<(value: Output, request: Publishers.Async.Request),Swift.Error>) -> Publishers.Async.Permission
        /// Checks whether the publisher is already cancelled or it is still operating.
        /// - returns: Boolean indicating whether the publisher has been already cancelled (`true`) or it is still active (`false`).
        public typealias CancelCheck = () -> Bool
        /// The closure type being stored for value transformation.
        /// - parameter value: The value received from the upstream.
        /// - parameter promise: The promise to call once the transformation is done.
        public typealias Closure = (_ value: Upstream.Output, _ isCancelled: @escaping CancelCheck, _ promise: @escaping Promise) -> Void
        
        /// The upstream publisher.
        public let upstream: Upstream
        /// The maximum number of parallel requests allowed.
        public let parallel: Subscribers.Demand
        /// The closure generating the downstream value.
        /// - note: The closure is kept in the publisher; therefore, if you keep the publisher around any reference in the closure will be kept too.
        public let closure: Closure
        /// Creates a publisher that transforms the incoming values. This transformation is asynchronous and it may entail several output values.
        ///
        /// The `parallel` parameter indicates how many upstream values shall be processed at the same time. It is also important to notice that the downstream demand is uphold. Therefore, if the downstream requests 3 values, and there are already 2 promises generating several values (while not completing), the following upstream values will be ignored.
        ///
        /// The only cases were values are promised not to be ignored are:
        /// - If `parallel` is `.max(1)` and the promise user looks for the `Permission` response before sending new values.
        /// - If a promise is just sending one output (similar to a `map` publisher).
        /// - precondition: `parallel` must be greater than zero.
        /// - parameter upstream: The event emitter to the publisher being created.
        /// - parameter parallel: The maximum number of parallel upstream value processing.
        /// - parameter transform: Closure in charge of transforming the values.
        @inlinable public init(upstream: Upstream, parallel: Subscribers.Demand, transform: @escaping Closure) {
            precondition(parallel > 0)
            self.upstream = upstream
            self.parallel = parallel
            self.closure = transform
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let conduit = Conduit(downstream: subscriber, parallel: self.parallel, closure: self.closure)
            self.upstream.subscribe(conduit)
        }
    }
}

extension Publishers.AsyncTryMap {
    /// Indication whether the transformation closure will continue emitting values (i.e. `.continue`) or it is done (i.e. `finished`).
    public enum Request: Equatable {
        /// The transformation closure will continue emitting values. Failing to do so will make the publisher to never complete nor process further upstream values.
        case `continue`
        /// The transformation closure is done and further upstream values may be processed.
        case finished
    }
    
    /// The permission returned by a promise.
    public enum Permission: ExpressibleByBooleanLiteral, Equatable {
        /// The transformation closure is allowed to send a new value.
        case allowed
        /// The transformation closure is forbidden to send a new value. If it tries to do so, it will get ignored.
        case forbidden
        
        public init(booleanLiteral value: BooleanLiteralType) {
            switch value {
            case true: self = .allowed
            case false: self = .forbidden
            }
        }
    }
}

extension Publishers.AsyncTryMap {
    /// Subscription representing an activated `AsyncTryMap` publisher.
    fileprivate final class Conduit<Downstream>: Subscription, Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        /// Enum listing all possible conduit states.
        @Lock private var state: State<WaitConfiguration,ActiveConfiguration>
        
        /// Creates a representation of an `AsyncTryMap` publisher.
        init(downstream: Downstream, parallel: Subscribers.Demand, closure: @escaping Closure) {
            self.state = .awaitingSubscription(.init(downstream: downstream, parallel: parallel, closure: closure))
        }
        
        deinit {
            self.cancel()
            self._state.deinitialize()
        }
        
        func receive(subscription: Subscription) {
            guard let config = self._state.activate(atomic: { .init(upstream: subscription, downstream: $0.downstream, parallel: $0.parallel, closure: $0.closure) }) else {
                return subscription.cancel()
            }
            config.downstream.receive(subscription: self)
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            self._state.lock()
            
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            config.demand.expected += demand
            
            guard case (let subscription?, let d) = config.calculateUpstreamDemand(), d > 0 else { return self._state.unlock() }
            config.demand.requested += d
            
            self._state.unlock()
            
            subscription.request(d)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            self._state.lock()
            
            guard let config = self.state.activeConfiguration else { self._state.unlock(); return .none }
            config.demand.requested -= 1
            
            // If there are already a maximum amount of parallel processing values, ignore the inconming value.
            guard config.demand.processing < config.parallel else { self._state.unlock(); return .none }
            config.demand.processing += 1
            
            guard case (.some, let d) = config.calculateUpstreamDemand() else { fatalError("\nAn input was received, although the upstream already disappeared\n") }
            config.demand.requested += d
            let closure = config.closure
            let (isCancelled, promise) = self.makeClosures()
            self._state.unlock()
            
            closure(input, isCancelled, promise)
            return d
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            self._state.lock()
            
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            config.upstream = nil
            config.demand.requested = .none
            
            if case .finished = completion, config.demand.processing > 0 { return self._state.unlock() }
            self.state = .terminated
            self._state.unlock()
            config.downstream.receive(completion: completion.mapError { $0 })
        }
        
        func cancel() {
            guard case .active(let config) = self._state.terminate() else { return }
            config.upstream?.cancel()
        }
    }
}

extension Publishers.AsyncTryMap.Conduit {
    /// - precondition: When this function is called `self` is within the lock and in an active state.
    private func makeClosures() -> (check: Publishers.AsyncTryMap<Upstream,Output>.CancelCheck, promise: Publishers.AsyncTryMap<Upstream,Output>.Promise) {
        typealias P = Publishers.AsyncTryMap<Upstream,Output>
        var isFinished = false
        
        let isCancelled: P.CancelCheck = { [weak self] in
            guard let self = self else { return true }
            self._state.lock()
            let result = self.state.isTerminated || isFinished
            self._state.unlock()
            return result
        }
        
        let promise: P.Promise = { [weak self] (result) in
            guard let self = self else {
                isFinished = true
                return .forbidden
            }
            
            self._state.lock()
            guard let config = self.state.activeConfiguration else {
                isFinished = true
                self._state.unlock()
                return .forbidden
            }
            
            let downstream = config.downstream
            config.demand.expected -= 1
            
            let (value, request): (Output, Publishers.Async.Request)
            switch result {
            case .success(let result):
                (value, request) = result
                self._state.unlock()
            case .failure(let error):
                isFinished = true
                config.upstream = nil
                config.demand.requested = .none
                self.state = .terminated
                self._state.unlock()
                downstream.receive(completion: .failure(error))
                return .forbidden
            }
            
            let receivedDemand = downstream.receive(value)
            
            self._state.lock()
            guard self.state.isActive else {
                isFinished = true
                self._state.unlock()
                return .forbidden
            }
            
            config.demand.expected += receivedDemand
            config.demand.processing -= 1
            
            let (s, d) = config.calculateUpstreamDemand()
            if case .continue = request, config.demand.expected > 0 {
                config.demand.processing += 1
                self._state.unlock()
                if let subscription = s, d > 1 { subscription.request(d - 1) }
                return .allowed
            }
            
            isFinished = true
            
            if let subscription = s {
                config.demand.requested += d
                self._state.unlock()
                if d > 0 { subscription.request(d) }
            } else {
                self._state.unlock()
                if config.demand.processing <= 0 { downstream.receive(completion: .finished) }
            }
            
            return .forbidden
        }
        
        return (isCancelled, promise)
    }
}

extension Publishers.AsyncTryMap.Conduit {
    /// Values needed for the subscription awaiting state.
    private struct WaitConfiguration {
        let downstream: Downstream
        let parallel: Subscribers.Demand
        let closure: Publishers.AsyncTryMap<Upstream,Output>.Closure
    }
    
    /// Values needed for the subscription active state.
    private final class ActiveConfiguration {
        /// The subscription used to manage the upstream back-pressure.
        var upstream: Subscription?
        /// The subscriber receiving the input and completion.
        let downstream: Downstream
        /// The maximum number of parallel requests allowed.
        let parallel: Subscribers.Demand
        /// The closure being called for each upstream value emitted.
        let closure: Publishers.AsyncTryMap<Upstream,Output>.Closure
        /// The values requested by the downstream and the values being processed at the moment.
        var demand: (requested: Subscribers.Demand, expected: Subscribers.Demand, processing: Int)
        
        /// Designated initializer providing the requried upstream and downstream.
        init(upstream: Subscription, downstream: Downstream, parallel: Subscribers.Demand, closure: @escaping Publishers.AsyncTryMap<Upstream,Output>.Closure) {
            self.upstream = upstream
            self.downstream = downstream
            self.parallel = parallel
            self.closure = closure
            self.demand = (.none, .none, 0)
        }
        
        /// Calculates how many values conduit wants.
        /// - remark: This method must be called within the conduit lock. It expects atomic access.
        /// - returns: The upstream subscription and the demand to perform. If `nil`, no operation shall be performed.
        func calculateUpstreamDemand() -> (subscription: Subscription?, demand: Subscribers.Demand) {
            // If there is no upstream or the upstream has been previously asked for an unlimited number of values, there is no need to request anything else.
            guard let upstream = self.upstream else { return (nil, .none) }
            guard let requested = self.demand.requested.max else { return (upstream, .none) }
            
            let inflight = requested + self.demand.processing
            // If the number of inflight requests is the same as the allowed parallel ones, don't ask for more.
            guard inflight < self.parallel else { return (upstream, .none) }
            
            let result = min(self.parallel, self.demand.expected) - inflight
            return (upstream, result)
        }
    }
}
