import Combine

extension Subscribers {
    /// A  simple subscriber that requests the given number of values upon subscription, always maintaining the same demand.
    public final class GraduatedSink<Input,Failure>: Subscriber, Cancellable where Failure:Error {
        /// The maximum allowed in-flight events.
        public let maxDemand: Subscribers.Demand
        /// The closure executed when a value is received.
        public private(set) var receiveValue: ((Input)->Void)?
        /// The closure executed when a completion event is received.
        public private(set) var receiveCompletion: ((Subscribers.Completion<Failure>)->Void)?
        /// The subscriber's state.
        @Lock private var state: State<Void,Configuration>
        
        /// Designated initializer specifying the maximum in-flight events.
        /// - precondition: `maxDemand` must be greater than zero.
        /// - parameter maxDemand: The maximum allowed in-flight events.
        /// - parameter receiveCompletion: The closure executed when a completion event is received.
        /// - parameter receiveValue: The closure executed when a value is received.
        public init(maxDemand: Subscribers.Demand, receiveCompletion: ((Subscribers.Completion<Failure>)->Void)? = nil, receiveValue: ((Input)->Void)? = nil) {
            precondition(maxDemand > 0)
            self.maxDemand = maxDemand
            self.receiveValue = receiveValue
            self.receiveCompletion = receiveCompletion
            self.state = .awaitingSubscription(())
        }
        
        deinit {
            self.cancel()
            self._state.deinitialize()
        }
        
        public func receive(subscription: Subscription) {
            guard case .some = self._state.activate(atomic: { _ in .init(upstream: subscription) }) else {
                return subscription.cancel()
            }
            subscription.request(self.maxDemand)
        }
        
        public func receive(_ input: Input) -> Subscribers.Demand {
            self.receiveValue?(input)
            return .max(1)
        }
        
        public func receive(completion: Subscribers.Completion<Failure>) {
            guard case .active = self._state.terminate() else { return }
            self.receiveValue = nil
            self.receiveCompletion?(completion)
            self.receiveCompletion = nil
        }
        
        public func cancel() {
            guard case .active = self._state.terminate() else { return }
            self.receiveValue = nil
            self.receiveCompletion = nil
        }
    }
}

extension Subscribers.GraduatedSink {
    /// Variables required during the *active* stage.
    private struct Configuration {
        /// Upstream subscription.
        let upstream: Subscription
    }
}
