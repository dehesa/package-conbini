import Combine

/// A publisher that never emits any values and just completes successfully or with a failure (depending on whether an error was thrown in the closure).
///
/// This publisher is used at the origin of a publisher chain and it only provides the value when it receives a request with a demand greater than zero.
public struct DeferredTryComplete<Output>: Publisher {
    public typealias Failure = Swift.Error
    /// The closure type being store for delayed execution.
    public typealias Closure = () throws -> Void
    
    /// Deferred closure.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    
    /// Creates a publisher that send a successful completion once it receives a positive request (i.e. a request greater than zero)
    public init() {
        self.closure = { return }
    }
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter closure: The closure which produces an empty successful completion or a failure (if it throws).
    public init(closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

extension DeferredTryComplete {
    /// The shadow subscription chain's origin.
    fileprivate struct Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @LockableState private var state: State<(),Configuration>
        /// Debug identifier.
        var combineIdentifier: CombineIdentifier { _state.combineIdentifier }
        
        init(downstream: Downstream, closure: @escaping Closure) {
            _state = .active(.init(downstream: downstream, closure: closure))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0,
                  case .active(let config) = _state.terminate() else { return }
            
            do {
                try config.closure()
            } catch let error {
                return config.downstream.receive(completion: .failure(error))
            }
            
            config.downstream.receive(completion: .finished)
        }
        
        func cancel() {
            _state.terminate()
        }
    }
}

extension DeferredTryComplete.Conduit {
    /// Values needed for the subscription active state.
    private struct Configuration {
        let downstream: Downstream
        let closure: DeferredTryComplete.Closure
    }
}
