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
    public init(closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func receive<S>(subscriber: S) where S: Subscriber, Output==S.Input, Failure==S.Failure {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
    
    /// The shadow subscription chain's origin.
    private final class Conduit<Downstream>: Subscription where Downstream: Subscriber, Failure==Downstream.Failure {
        @SubscriptionState
        private var state: (downstream: Downstream, closure: Closure)
        
        init(downstream: Downstream, closure: @escaping Closure) {
            self._state = .init(wrappedValue: (downstream, closure))
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, let (downstream, closure) = self._state.remove() else { return }
            
            do {
                try closure()
            } catch let error {
                return downstream.receive(completion: .failure(error))
            }
            
            downstream.receive(completion: .finished)
        }
        
        func cancel() {
            self._state.remove()
        }
    }
}
