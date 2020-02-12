import Combine
import Foundation

extension Publishers {
    /// Executes child publishers one at a time through the use of backpressure management.
    /// ```
    /// [firstEndpoint, secondEnpoint, thirdEndpoint]
    ///     .publisher
    ///     .sequentialFlatMap { $0 }
    /// ```
    ///
    /// If the upstream emits values without regard to backpressure (e.g. `Subject`s), `SequentialFlatMap` buffers them internally and execute them as expected (i.e. sequentially).
    /// - attention: The stream only completes when both the upstream and the children publishers complete.
    public struct SequentialFlatMap<Child,Upstream>: Publisher where Child:Publisher, Upstream:Publisher, Child.Failure==Upstream.Failure {
        public typealias Output = Child.Output
        public typealias Failure = Child.Failure
        
        /// The publisher from which this publisher receives children.
        private let upstream: Upstream
        /// The closure generating the publisher emitting downstream.
        private let closure: (Upstream.Output) -> Child
        
        /// Designated initializer passing the publisher emitting values received here and the closure creating the *child* publisher.
        /// - parameter upstream: The publisher from which this publisher receives children.
        /// - parameter transform: Closure in charge of transforming the upstream value into a new publisher.
        /// - attention: Be mindful of variables stored strongly within the closure. The closure will be kept until a termination event (or cancel) reaches this publisher.
        internal init(upstream: Upstream, transform: @escaping (Upstream.Output)->Child) {
            self.upstream = upstream
            self.closure = transform
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let subscriber = UpstreamSubscriber(conduit: .init(downstream: subscriber, closure: self.closure))
            upstream.subscribe(subscriber)
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscription representing the `SequentialFlatMap` publisher.
    fileprivate final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        typealias TransformClosure = (_ value: Upstream.Output) -> Child
        
        /// Enum listing all possible conduit states.
        @LockableState var state: State<WaitConfiguration,ActiveConfiguration>
        /// Shared variables between the conduit, upstream subscriber, and child subscriber.
        var shared: LockableState<WaitConfiguration,ActiveConfiguration> { _state }
        
        /// Designated initializer passing the downstream subscriber.
        /// - parameter downstream: The `Subscriber` receiving the outcome of this *described* publisher.
        init(downstream: Downstream, closure: @escaping TransformClosure) {
            _state = .awaitingSubscription(.init(downstream: downstream, closure: closure))
        }
        
        deinit {
            self.cancel()
        }
        
        func cancel() {
            guard case .active(let config) = _state.terminate() else { return }
            if case .active(let child) = config.child { child.cancel() }
            config.upstream?.cancel()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            _state.lock()
            guard let config = self.state.activeConfiguration else { return _state.unlock() }
            config.demand += demand
            
            let action: RequestAction?
            switch config.child {
            case .active(let child):
                action = .signal(subscription: child)
                config.demand -= 1      // -todo: Demand is being passed to a child and it might not be used
            case .terminated where config.waitingQueue.isEmpty:
                action = .signal(subscription: config.upstream)
            case .terminated:
                action = .generateChild(value: config.waitingQueue.removeFirst(), closure: config.closure)
                config.child = .awaitingSubscription(())
            case .awaitingSubscription:
                action = nil
            }
            _state.unlock()
            
            switch action {
            case .signal(let subscription): subscription?.request(.max(1))
            case .generateChild(let value, let closure): closure(value).subscribe(ChildSubscriber(conduit: self))
            case .none: break
            }
        }
        
        private enum RequestAction {
            case signal(subscription: Subscription?)
            case generateChild(value: Upstream.Output, closure: TransformClosure)
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscriber sent upstream to receive its inputs and completion events.
    private struct UpstreamSubscriber<Downstream>: Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Strong bond to the `Conduit` instance, so it is kept alive between upstream subscription and the subscription acknowledgement.
        let conduit: Conduit<Downstream>
        /// Debug identifier.
        var combineIdentifier: CombineIdentifier { self.conduit.combineIdentifier }
        
        /// Designated initializer for this helper establishing the strong bond between the `Conduit` and the created helper.
        init(conduit: Conduit<Downstream>) {
            self.conduit = conduit
        }
        
        func receive(subscription: Subscription) {
            let config = self.conduit.shared.activate { .init(upstream: subscription, downstream: $0.downstream, closure: $0.closure) }
            config?.downstream.receive(subscription: self.conduit)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            let shared = self.conduit.shared
            
            shared.lock()
            guard let config = shared.wrappedValue.activeConfiguration else { shared.unlock(); return .none }
            
            config.waitingQueue.append(input)
            guard case .terminated = config.child, config.demand > 0 else { shared.unlock(); return .none }
            
            let closure = config.closure
            let value = config.waitingQueue.removeFirst()
            config.child = .awaitingSubscription(())
            shared.unlock()
            
            closure(value).subscribe(ChildSubscriber(conduit: self.conduit))
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            let shared = self.conduit.shared
            
            shared.lock()
            guard let config = shared.wrappedValue.activeConfiguration else { return shared.unlock() }
            
            switch completion {
            case .failure(let upstreamError):
                self.conduit.state = .terminated
                shared.unlock()
                if case .active(let child) = config.child { child.cancel() }
                config.downstream.receive(completion: .failure(upstreamError))
            case .finished:
                if config.waitingQueue.isEmpty, case .terminated = config.child {
                    self.conduit.state = .terminated
                    shared.unlock()
                    config.downstream.receive(completion: .finished)
                } else {
                    config.upstream = nil
                    shared.unlock()
                }
            }
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscriber receiving the children inputs and completion events.
    private struct ChildSubscriber<Downstream>: Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Strong bond to the `Conduit` instance, so it is kept alive between subscription and the subscription acknowledgement.
        let conduit: Conduit<Downstream>
        /// Debug identifier.
        var combineIdentifier: CombineIdentifier { self.conduit.combineIdentifier }
        
        /// Designated initializer for this helper establishing the strong bond between the `Conduit` and the created helper.
        init(conduit: Conduit<Downstream>) {
            self.conduit = conduit
        }
        
        func receive(subscription: Subscription) {
            let shared = self.conduit.shared
            
            shared.lock()
            guard let config = shared.wrappedValue.activeConfiguration else { return shared.unlock() }
            guard case .awaitingSubscription = config.child else { fatalError() }
            
            config.child = .active(subscription)
            guard config.demand > 0 else { return shared.unlock() }
            
            config.demand -= 1
            shared.unlock()
            subscription.request(.max(1))
        }
        
        func receive(_ input: Child.Output) -> Subscribers.Demand {
            let shared = self.conduit.shared
            
            shared.lock()
            guard let configFirst = shared.wrappedValue.activeConfiguration, case .active = configFirst.child else {
                shared.unlock()
                return .none
            }
            
            let downstream = configFirst.downstream
            shared.unlock()
            let receivedDemand = downstream.receive(input)
            
            shared.lock()
            guard let configSecond = shared.wrappedValue.activeConfiguration, case .active = configSecond.child else {
                shared.unlock()
                return .none
            }
            
            configSecond.demand += receivedDemand
            guard configSecond.demand > 0 else { shared.unlock(); return .none }
            
            configSecond.demand -= 1
            shared.unlock()
            return .max(1)
        }
        
        func receive(completion: Subscribers.Completion<Child.Failure>) {
            let shared = self.conduit.shared
            
            shared.lock()
            guard let config = shared.wrappedValue.activeConfiguration else { return shared.unlock() }
            
            switch completion {
            case .failure(let error):
                self.conduit.state = .terminated
                shared.unlock()
                config.downstream.receive(completion: .failure(error))
            case .finished:
                if !config.waitingQueue.isEmpty {
                    config.child = .awaitingSubscription(())
                    
                    let closure = config.closure
                    let value = config.waitingQueue.removeFirst()
                    shared.unlock()
                    
                    closure(value).subscribe(ChildSubscriber(conduit: self.conduit))
                } else if let upstream = config.upstream {
                    config.child = .terminated
                    shared.unlock()
                    upstream.request(.max(1))
                } else {
                    self.conduit.state = .terminated
                    shared.unlock()
                    config.downstream.receive(completion: .finished)
                }
            }
        }
    }
}

extension Publishers.SequentialFlatMap.Conduit {
    /// Values need for the subscription awaiting state.
    struct WaitConfiguration {
        /// The subscriber receiving the input and completion.
        let downstream: Downstream
        /// The closure generating the child publisher.
        let closure: TransformClosure
    }
    
    /// Values needed for the subscription active state.
    final class ActiveConfiguration {
        /// The subscription used to manage the upstream back-pressure.
        var upstream: Subscription?
        /// The child state managing the sequential children.
        var child: State<Void,Subscription>
        /// The subscriber receiving the input and completion.
        let downstream: Downstream
        /// The closure generating the child publisher.
        let closure: TransformClosure
        /// The children that has been sent but not yet executed.
        var waitingQueue: [Upstream.Output]
        /// The demand requested by the downstream so far.
        var demand: Subscribers.Demand
        /// Designated initializer providing the required upstream and downstream. All other information is set with the defaults.
        init(upstream: Subscription, downstream: Downstream, closure: @escaping TransformClosure) {
            self.upstream = upstream
            self.child = .terminated
            self.downstream = downstream
            self.closure = closure
            self.waitingQueue = []
            self.demand = .none
        }
    }
}
