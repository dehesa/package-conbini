import Combine

/// A publisher that never emits any values and just completes successfully or with a failure (depending on whether an error was thrown in the closure).
///
/// This publisher is used at the origin of a publisher chain and it only provides the value when it receives a request with a demand greater than zero.
public struct DeferredTryComplete<Output>: Publisher {
    public typealias Failure = Swift.Error
    /// The closure type being store for delayed execution.
    public typealias Closure = () throws -> Void
    
    /// Deferred closure.
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
    public let closure: Closure
    
    /// Creates a publisher that send a successful completion once it receives a positive request (i.e. a request greater than zero)
    public init() {
        self.closure = { return }
    }
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter closure: The closure which produces an empty successful completion or a failure (if it throws).
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
    @inlinable public init(closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

fileprivate extension DeferredTryComplete {
    /// The shadow subscription chain's origin.
    final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @Lock private var state: State<Void,_Configuration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self.state = .active(_Configuration(downstream: downstream, closure: closure))
        }
        
        deinit {
            self._state.deinitialize()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, case .active(let config) = self._state.terminate() else { return }
            
            do {
                try config.closure()
            } catch let error {
                return config.downstream.receive(completion: .failure(error))
            }
            
            config.downstream.receive(completion: .finished)
        }
        
        func cancel() {
            self._state.terminate()
        }
    }
}

private extension DeferredTryComplete.Conduit {
    /// Values needed for the subscription's active state.
    struct _Configuration {
        /// The downstream subscriber awaiting any value and/or completion events.
        let downstream: Downstream
        /// The closure generating the successful/failure completion.
        let closure: DeferredTryComplete.Closure
    }
}
