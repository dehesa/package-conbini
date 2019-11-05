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
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, error: self.error)
        subscriber.receive(subscription: subscription)
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

extension Complete {
    /// The shadow subscription chain's origin.
    private struct Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible subscription states.
        @LockableState private var state: State<(),Configuration>
        /// Sets up the guarded state.
        /// - parameter downstream: Downstream subscriber receiving the data from this instance.
        /// - parameter error: The success or error to be sent upon subscription.
        init(downstream: Downstream, error: Downstream.Failure?) {
            _state = .active(.init(downstream: downstream, error: error))
        }
        
        var combineIdentifier: CombineIdentifier {
            _state.combineIdentifier
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0,
                  case .active(let config) = _state.terminate() else { return }
            config.downstream.receive(completion: config.error.map { .failure($0) } ?? .finished)
        }
        
        func cancel() {
            _state.terminate()
        }
        
        /// The configuration for the subscription active state.
        private struct Configuration {
            let downstream: Downstream
            let error: Downstream.Failure?
        }
    }
}
