import Combine

extension Publishers {
    /// A publisher that performs the specified closure when the publisher completes or get cancelled.
    public struct HandleEnd<Upstream>: Publisher where Upstream:Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        /// Closure getting executed once the publisher receives a completion event or when the publisher gets cancelled.
        /// - parameter completion: A completion event if the publisher completes (whether successfully or not), or `nil` in case the publisher is cancelled.
        public typealias Closure = (_ completion: Subscribers.Completion<Failure>?) -> Void
        
        /// Publisher emitting the events being received here.
        public let upstream: Upstream
        /// Closure executing the *ending* event.
        public let closure: Closure
        
        /// Designated initializer providing the upstream publisher and the closure receiving the *ending* event.
        /// - parameter upstream: Upstream publisher chain.
        /// - parameter handle: A closure that executes when the publisher receives a completion event or when the publisher gets cancelled.
        public init(upstream: Upstream, handle: @escaping Closure) {
            self.upstream = upstream
            self.closure = handle
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let conduit = Conduit(downstream: subscriber, closure: self.closure)
            self.upstream.subscribe(conduit)
        }
    }
}

extension Publishers.HandleEnd {
    /// Represents an active `HandleEnd` publisher taking both the role of `Subscriber` (for upstream publishers) and `Subscription` (for downstream subscribers).
    fileprivate final class Conduit<Downstream>: Subscription, Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        /// Enum listing all possible states.
        @LockableState private var state: State<WaitConfiguration,ActiveConfiguration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self.state = .awaitingSubscription(.init(closure: closure, downstream: downstream))
        }
        
        deinit {
            self.cancel()
        }
        
        func receive(subscription: Subscription) {
            guard let config = self._state.activate(locking: { ActiveConfiguration(upstream: subscription, closure: $0.closure, downstream: $0.downstream) }) else { return }
            config.downstream.receive(subscription: self)
        }
        
        func request(_ demand: Subscribers.Demand) {
            self._state.lock()
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            config.upstream.request(demand)
            self._state.unlock()
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            self._state.lock()
            guard let config = self.state.activeConfiguration else { self._state.unlock(); return .unlimited }
            self._state.unlock()
            
            return config.downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            switch self._state.terminate() {
            case .active(let config):
                config.closure(completion)
                config.downstream.receive(completion: completion)
            case .terminated: return
            case .awaitingSubscription: fatalError()
            }
        }
        
        func cancel() {
            switch self._state.terminate() {
            case .awaitingSubscription(let config):
                config.closure(nil)
            case .active(let config):
                config.closure(nil)
                config.upstream.cancel()
            case .terminated: return
            }
        }
    }
}

extension Publishers.HandleEnd.Conduit {
    /// The necessary variables during the *awaiting* stage.
    private struct WaitConfiguration {
        /// The closure being executed only once when the publisher completes or get cancelled.
        let closure: Publishers.HandleEnd<Upstream>.Closure
        /// The subscriber further down the chain.
        let downstream: Downstream
    }
    
    /// The necessary variables during the *active* stage.
    private struct ActiveConfiguration {
        /// The upstream subscription.
        let upstream: Subscription
        /// The closure being executed only once when the publisher completes or get cancelled.
        let closure: Publishers.HandleEnd<Upstream>.Closure
        /// The subscriber further down the chain.
        let downstream: Downstream
    }
}
