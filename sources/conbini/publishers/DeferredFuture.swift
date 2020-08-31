import Combine

/// A publisher that may produce a value before completing (whether successfully or with a failure).
///
/// This publisher only executes the stored closure when it receives a request with a demand greater than zero. Right after the closure execution, the closure is removed and clean up.
public struct DeferredFuture<Output,Failure:Swift.Error>: Publisher {
    /// The promise returning the value (or failure) of the whole publisher.
    public typealias Promise = (Result<Output,Failure>) -> Void
    /// The closure type being store for delayed execution.
    public typealias Closure = (_ promise: @escaping Promise) -> Void
    
    /// Deferred closure.
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
    public let closure: Closure
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter attempToFulfill: Closure in charge of generating the value to be emitted.
    /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted). 
    @inlinable public init(_ attempToFulfill: @escaping Closure) {
        self.closure = attempToFulfill
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

fileprivate extension DeferredFuture {
    /// The shadow subscription chain's origin.
    final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @Lock private var state: State<Void,_Configuration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self.state = .active(_Configuration(downstream: downstream, step: .awaitingExecution(closure)))
        }
        
        deinit {
            self._state.deinitialize()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            self._state.lock()
            guard var config = self.$state.activeConfiguration,
                  case .awaitingExecution(let closure) = config.step else { return self._state.unlock() }
            config.step = .awaitingPromise
            self.$state = .active(config)
            self._state.unlock()
            
            closure { [weak self] (result) in
                guard let self = self else { return }
                
                guard case .active(let config) = self._state.terminate() else { return }
                guard case .awaitingPromise = config.step else { fatalError() }
                
                switch result {
                case .success(let value):
                    _ = config.downstream.receive(value)
                    config.downstream.receive(completion: .finished)
                case .failure(let error):
                    config.downstream.receive(completion: .failure(error))
                }
            }
        }
        
        func cancel() {
            self._state.terminate()
        }
    }
}

private extension DeferredFuture.Conduit {
    /// Values needed for the subscription's active state.
    struct _Configuration {
        /// The downstream subscriber awaiting any value and/or completion events.
        let downstream: Downstream
        /// The state on the promise execution
        var step: Step
        
        enum Step {
            /// The closure hasn't been executed.
            case awaitingExecution(_ closure: DeferredFuture<Output,Failure>.Closure)
            /// The closure has been executed, but no promise has been received yet.
            case awaitingPromise
        }
    }
}
