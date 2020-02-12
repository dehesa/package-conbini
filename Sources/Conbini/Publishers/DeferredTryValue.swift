import Combine

/// A publisher emitting the value generated by a given closure followed by a successful completion. If the closure throws an error, the publisher will complete with a failure.
///
/// This publisher is used at the origin of a publisher chain and it only executes the passed closure when it receives a request with a demand greater than zero.
public struct DeferredTryValue<Output>: Publisher {
    public typealias Failure = Swift.Error
    /// The closure type being store for delayed execution.
    public typealias Closure = () throws -> Output
    /// Deferred closure.
    /// - attention: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    
    /// Creates a publisher which will a value and completes successfully, or just fail depending on the result of the given closure.
    /// - parameter closure: Closure in charge of generating the value to be emitted.
    /// - attention: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

extension DeferredTryValue {
    /// The shadow subscription chain's origin.
    fileprivate final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @LockableState private var state: State<Void,Configuration>
        
        /// Sets up the guarded state.
        /// - parameter downstream: Downstream subscriber receiving the data from this instance.
        /// - parameter closure: Closure in charge of generating the emitted value.
        init(downstream: Downstream, closure: @escaping Closure) {
            self._state = .active(.init(downstream: downstream, closure: closure))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, case .active(let config) = self._state.terminate() else { return }
            
            let input: Output
            do {
                input = try config.closure()
            } catch let error {
                return config.downstream.receive(completion: .failure(error))
            }
            
            _ = config.downstream.receive(input)
            config.downstream.receive(completion: .finished)
        }
        
        func cancel() {
            self._state.terminate()
        }
    }
}

extension DeferredTryValue.Conduit {
    /// Values needed for the subscription active state.
    private struct Configuration {
        let downstream: Downstream
        let closure: DeferredTryValue.Closure
    }
}
