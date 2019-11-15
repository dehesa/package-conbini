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
    private let closure: Closure
    
    /// Creates a publisher that send a value and completes successfully or just fails depending on the result of the given closure.
    /// - parameter closure: Closure in charge of generating the value to be emitted.
    /// - attention: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    public init(_ attempToFulfill: @escaping Closure) {
        self.closure = attempToFulfill
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, Output==S.Input, Failure==S.Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

extension DeferredFuture {
    /// The shadow subscription chain's origin.
    private struct Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @LockableState private var state: State<(),Configuration>
        /// Debug identifier.
        var combineIdentifier: CombineIdentifier { _state.combineIdentifier }
        
        init(downstream: Downstream, closure: @escaping Closure) {
            _state = .active(.init(downstream: downstream, step: .awaitingDemand(closure: closure)))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            _state.lock()
            guard let c = self.state.activeConfiguration,
                case .awaitingDemand(let closure) = c.step else { return _state.unlock() }
            self.state = .active(.init(downstream: c.downstream, step: .awaitingResult))
            _state.unlock()
            
            closure { [weak lockableState = self._state] (result) -> Void in
                guard let s = lockableState else { return }
                
                s.lock()
                guard let config = s.wrappedValue.activeConfiguration else { return s.unlock() }
                guard case .awaitingResult = config.step else { fatalError() }
                s.wrappedValue = .terminated
                s.unlock()
                
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
            _state.terminate()
        }
        
        /// Values needed for the subscription active state.
        private struct Configuration {
            let downstream: Downstream
            let step: Step
            
            enum Step {
                case awaitingDemand(closure: Closure)
                case awaitingResult
            }
        }
    }
}
