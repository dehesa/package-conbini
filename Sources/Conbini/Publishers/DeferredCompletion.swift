import Combine

/// A publisher returning the result of a given closure only executed on the first positive demand.
///
/// This publisher is used at the origin of a publisher chain and it only provides the value when it receives a request with a demand greater than zero.
public struct DeferredCompletion: Publisher {
    public typealias Output = Never
    public typealias Failure = Swift.Error
    /// The closure type being store for delated execution.
    public typealias Closure = () throws -> Void
    /// Deferred closure.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    
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

extension DeferredCompletion {
    /// The shadow subscription chain's origin.
    private struct Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @Locked private var state: State<(),Configuration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            _state = .init(active: .init(downstream: downstream, closure: closure))
        }
        
        var combineIdentifier: CombineIdentifier {
            _state.combineIdentifier
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
        
        /// The configuration for the subscription active state.
        private struct Configuration {
            let downstream: Downstream
            let closure: Closure
        }
    }
}
