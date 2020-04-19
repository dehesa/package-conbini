import Combine

/// A publisher that eventually produces a single value and then finishes or fails.
///
/// This publisher is used at the origin of a publisher chain and it only executes the closure when it receives a request with a demand greater than zero.
public struct DeferredFuture<Output,Failure:Swift.Error>: Publisher {
    /// The promise returning the value (or failure) of the whole publisher.
    public typealias Promise = (Result<Output,Failure>) -> Void
    /// The closure type being store for delayed execution.
    public typealias Closure = (_ promise: @escaping Promise) -> Void
    /// Deferred closure.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    public let closure: Closure
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter closure: Closure in charge of generating the value to be emitted.
    /// - attention: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    @inlinable public init(_ attempToFulfill: @escaping Closure) {
        self.closure = attempToFulfill
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

extension DeferredFuture {
    /// The shadow subscription chain's origin.
    fileprivate final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @Lock private var state: State<Void,Configuration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self.state = .active(.init(downstream: downstream, step: .awaitingDemand(closure: closure)))
        }
        
        deinit {
            self._state.deinitialize()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            self._state.lock()
            guard var config = self.state.activeConfiguration,
                  case .awaitingDemand(let closure) = config.step else { return self._state.unlock() }
            config.step = .awaitingResult
            self.state = .active(config)
            self._state.unlock()
            
            closure { [weak self] (result) in
                guard let self = self else { return }
                
                self._state.lock()
                guard let config = self.state.activeConfiguration else { return self._state.unlock() }
                self.state = .terminated
                self._state.unlock()
                
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

extension DeferredFuture.Conduit {
    /// Values needed for the subscription active state.
    private struct Configuration {
        let downstream: Downstream
        var step: Step
        
        enum Step {
            case awaitingDemand(closure: DeferredFuture<Output,Failure>.Closure)
            case awaitingResult
        }
    }
}
