import Combine

/// A publisher returning the result of a given closure only executed on the first positive demand.
///
/// This publisher is used at the origin of a publisher chain and it only provides the value when it receives a request with a demand greater than zero.
public struct DeferredResult<Output,Failure:Swift.Error>: Publisher {
    /// The closure type being store for delayed execution.
    public typealias Closure = () -> Result<Output,Failure>
    /// Deferred closure.
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted). 
    public let closure: Closure
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter closure: Closure in charge of generating the value to be emitted.
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
    @inlinable public init(closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

fileprivate extension DeferredResult {
    /// The shadow subscription chain's origin.
    final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @ConduitLock private var state: ConduitState<Void,_Configuration>
        
        /// Designated initializer passing the state configuration values.
        init(downstream: Downstream, closure: @escaping Closure) {
            self.state = .active(_Configuration(downstream: downstream, closure: closure))
        }
        
        deinit {
            self._state.invalidate()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, case .active(let config) = self._state.terminate() else { return }
            
            switch config.closure() {
            case .success(let value):
                _ = config.downstream.receive(value)
                config.downstream.receive(completion: .finished)
            case .failure(let error):
                config.downstream.receive(completion: .failure(error))
            }
        }
        
        func cancel() {
            self._state.terminate()
        }
    }
}

private extension DeferredResult.Conduit {
    /// Values needed for the subscription's active state.
    struct _Configuration {
        /// The downstream subscriber awaiting any value and/or completion events.
        let downstream: Downstream
        /// The closure generating the successful/failure completion.
        let closure: DeferredResult.Closure
    }
}
