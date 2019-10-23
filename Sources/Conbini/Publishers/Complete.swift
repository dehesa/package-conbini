import Combine

/// A publisher that never emits any values and just completes successfully or with a failure (depending on whether an error was provided in the initializer).
///
/// This publisher is used at the origin of a chain and it only provides the completion/failure when it receives a request with a deman greater than zero.
public struct Complete<Output,Failure:Swift.Error>: Publisher {
    /// The error to send as a failure; otherwise the publisher completes successfully.
    private let error: Failure?
    
    /// Creates a publisher that completes as soon as it receives a demand from a subscriber.
    /// - parameter error: The error to send as a failure; otherwise, it completes successfully.
    public init(error: Failure?) {
        self.error = error
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, Output==S.Input, Failure==S.Failure {
        let subscription = Conduit(downstream: subscriber, error: self.error)
        subscriber.receive(subscription: subscription)
    }
    
    /// The shadow subscription chain's origin.
    private final class Conduit<Downstream>: Subscription where Downstream:Subscriber {
        @SubscriptionState
        private var state: (downstream: Downstream, error: Downstream.Failure?)
        /// Sets up the guarded state.
        /// - parameter downstream: Downstream subscriber receiving the data from this instance.
        /// - parameter error: The success or error to be sent upon subscription.
        init(downstream: Downstream, error: Downstream.Failure?) {
            self._state = .init(wrappedValue: (downstream, error))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, let (downstream, error) = self._state.remove() else { return }
            downstream.receive(completion: error.map { .failure($0) } ?? .finished)
        }
        
        func cancel() {
            self._state.remove()
        }
    }
}

extension Complete where Output==Never, Failure==Never {
    /// Creates a publisher that completes successfully as soon as it receives a demand from a subscriber.
    ///
    /// This will perform a similar operation to an `Empty` publisher with its `completeImmediately` property set to `true`.
    public init() {
        self.error = nil
    }
}

extension Complete where Output==Never {
    /// Creates a publisher that completes with a failure as soon as it receives a demand from a subscriber.
    ///
    /// This will perform a similar operation to `Fail`.
    public init(error: Failure) {
        self.error = error
    }
}
