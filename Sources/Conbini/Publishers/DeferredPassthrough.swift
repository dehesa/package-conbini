import Combine
import Foundation

/// Similar to a `Passthrough` subject with the difference that the given closure will only get activated once the first positive demand is received.
///
/// There are some interesting quirks to this publisher:
/// - Each subscription to the publisher will get its own `Passthrough` subject.
/// - The `Passthrough` subject passed on the closure is already *chained* and can start forwarding values right away.
/// - The given closure will receive the `Passthrough` at the origin of the chain so it can be used to send information downstream.
/// - The closure will get *cleaned up* as soon as it returns.
/// - remark: Please notice, the pipeline won't complete if the subject within the closure doesn't send `.send(completion:)`.
public struct DeferredPassthrough<Output,Failure:Swift.Error>: Publisher {
    /// The closure type being store for delayed execution.
    public typealias Closure = (PassthroughSubject<Output,Failure>) -> Void
    
    /// Publisher's closure storage.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    /// Creates a publisher that sends
    /// - parameter setup: The closure for delayed execution.
    /// - remark: Please notice, the pipeline won't complete if the subject within the closure doesn't send `.send(completion:)`.
    public init(_ setup: @escaping Closure) {
        self.closure = setup
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, S.Failure==Failure, S.Input==Output {
        let upstream = PassthroughSubject<Output,Failure>()
        let conduit = Conduit(upstream: upstream, downstream: subscriber, closure: self.closure)
        upstream.subscribe(conduit)
    }
}

extension DeferredPassthrough {
    /// Internal Shadow subscription catching all messages from downstream and forwarding them upstream.
    fileprivate final class Conduit<Downstream>: Subscription, Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @LockableState private var state: State<WaitConfiguration,ActiveConfiguration>
        
        /// Designated initializer passing all the needed info (except the upstream subscription).
        init(upstream: PassthroughSubject<Output,Failure>, downstream: Downstream, closure: @escaping Closure) {
            self._state = .awaitingSubscription(.init(upstream: upstream, downstream: downstream, closure: closure))
        }
        
        deinit {
            self.cancel()
        }
        
        func receive(subscription: Subscription) {
            guard let config = self._state.activate(locking: { .init(upstream: subscription, downstream: $0.downstream, setup: ($0.upstream, $0.closure)) }) else { return }
            config.downstream.receive(subscription: self)
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            self._state.lock()
            guard let config = self.state.activeConfiguration else { return self._state.unlock() }
            self.state = .active(.init(upstream: config.upstream, downstream: config.downstream, setup: nil))
            self._state.unlock()
            
            config.upstream.request(demand)
            guard let (subject, closure) = config.setup else { return }
            closure(subject)
        }
        
        func receive(_ input: Output) -> Subscribers.Demand {
            self._state.lock()
            guard let config = self.state.activeConfiguration else {
                self._state.unlock()
                return .none
            }
            self._state.unlock()
            return config.downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard case .active(let config) = self._state.terminate() else { return }
            config.downstream.receive(completion: completion)
        }
        
        func cancel() {
            guard case .active(let config) = self._state.terminate() else { return }
            config.upstream.cancel()
        }
    }
}

extension DeferredPassthrough.Conduit {
    /// Values needed for the subscription awaiting state.
    private struct WaitConfiguration {
        let upstream: PassthroughSubject<Output,Failure>
        let downstream: Downstream
        let closure: DeferredPassthrough.Closure
    }
    
    /// Values needed for the subscription active state.
    private struct ActiveConfiguration {
        typealias Setup = (subject: PassthroughSubject<Output,Failure>, closure: DeferredPassthrough.Closure)
        
        let upstream: Subscription
        let downstream: Downstream
        var setup: Setup?
    }
}
