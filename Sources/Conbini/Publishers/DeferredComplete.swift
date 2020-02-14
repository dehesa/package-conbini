import Combine

/// A publisher that never emits any values and just completes successfully or with a failure (depending on whether an error was returned in the closure).
///
/// This publisher is used at the origin of a publisher chain and it only provides the value when it receives a request with a demand greater than zero.
public struct DeferredComplete<Output,Failure>: Publisher where Failure:Swift.Error {
    /// The closure type being store for delayed execution.
    public typealias Closure = () -> Failure?
    
    /// Deferred closure.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    public let closure: Closure
    
    /// Creates a publisher that send a successful completion once it receives a positive request (i.e. a request greater than zero)
    public init() {
        self.closure = { nil }
    }
    
    /// Creates a publisher that completes successfully or fails depending on the result of the given closure.
    /// - parameter output: The output type of this *empty* publisher. It is given here as convenience, since it may help compiler inferral.
    /// - parameter closure: The closure which produces an empty successful completion (if it returns `nil`) or a failure (if it returns an error).
    public init(output: Output.Type = Output.self, closure: @escaping Closure) {
        self.closure = closure
    }
    
    /// Creates a publisher that fails with the error provided.
    /// - parameter error: *Autoclosure* that will get executed on the first positive request (i.e. a request greater than zero).
    public init(error: @autoclosure @escaping ()->Failure) {
        self.closure = { error() }
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
}

extension DeferredComplete {
    /// The shadow subscription chain's origin.
    fileprivate final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @Lock private var state: State<Void,Configuration>
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self._state = .init(wrappedValue: .active(.init(downstream: downstream, closure: closure)))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, case .active(let config) = self._state.terminate() else { return }
            
            if let error = config.closure() {
                return config.downstream.receive(completion: .failure(error))
            } else {
                return config.downstream.receive(completion: .finished)
            }
        }
        
        func cancel() {
            self._state.terminate()
        }
    }
}

extension DeferredComplete.Conduit {
    /// Values needed for the subscription active state.
    private struct Configuration {
        let downstream: Downstream
        let closure: DeferredComplete.Closure
    }
}
