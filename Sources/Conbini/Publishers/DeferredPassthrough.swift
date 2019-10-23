import Combine
import Foundation

/// Similar to a `Passthrough` subject with the difference that the given closure will only get activated once the first positive demand is received.
///
/// There are some interesting quirks to this publisher:
/// - Each subscription to the publisher will get its own `Passthrough` subject.
/// - The `Passthrough` subject passed on the closure is already *chained* and can start forwarding values right away.
/// - The given closure will receive the `Passthrough` at the origin of the chain so it can be used to send information downstream.
/// - The closure will get *cleaned up* as soon as it returns.
public struct DeferredPassthrough<Output,Failure:Swift.Error>: Publisher {
    /// The closure type being store for delated execution.
    public typealias Closure = (PassthroughSubject<Output,Failure>) -> Void
    /// Publisher's closure storage.
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    /// Creates a publisher that sends
    /// - parameter setup: The closure for delayed execution.
    public init(_ setup: @escaping Closure) {
        self.closure = setup
    }
    
    public func receive<S>(subscriber: S) where S:Subscriber, Failure==S.Failure, Output==S.Input {
        let subscription = Conduit(downstream: subscriber, closure: self.closure)
        subscriber.receive(subscription: subscription)
    }
    
    /// Internal Shadow subscription catching all messages from downstream and forwarding them upstream.
    private final class Conduit<Downstream>: Subscription, Subscriber where Downstream: Subscriber, Failure==Downstream.Failure, Output==Downstream.Input {
        /// Lock used to modify `state` (exclusively).
        private var lock: os_unfair_lock
        /// Enum listing all possible subscription states.
        private var state: State
        
        /// Designated initializer passing all the needed info (except the upstream subscription).
        init(downstream: Downstream, closure: @escaping Closure) {
            self.lock = .init()
            self.state = .inactive(downstream: downstream, closure: closure)
        }
        
        // Stage 1: Receive request from downstream. This function can also be called at almost any point.
        func request(_ demand: Subscribers.Demand) {
            os_unfair_lock_lock(&self.lock)
            
            switch self.state {
            case .inactive(let downstream, let closure) where demand > 0:
                let subject = PassthroughSubject<Output,Failure>()
                self.state = .setup(downstream: downstream, closure: closure, subject: subject, demand: demand)
                os_unfair_lock_unlock(&self.lock)
                subject.subscribe(self)
            case .setup(let downstream, let closure, let subject, let demand):
                self.state = .setup(downstream: downstream, closure: closure, subject: subject, demand: demand)
                os_unfair_lock_unlock(&self.lock)
            case .active(let upstream, let downstream, let setup):
                var deferred: State.SetUp? = nil
                if let toSetup = setup, demand > 0 {
                    self.state = .active(upstream: upstream, downstream: downstream, setup: nil)
                    deferred = toSetup
                }
                os_unfair_lock_unlock(&self.lock)
                upstream.request(demand)
                guard let (closure, subject) = deferred else { return }
                closure(subject)
            case .cancelled, .inactive:
                os_unfair_lock_unlock(&self.lock)
            }
        }
        
        // Stage 2: Receive subscription from the `Passthrough` subject. This function can only be called on `.setup` or `.cancelled` state.
        func receive(subscription: Subscription) {
            os_unfair_lock_lock(&self.lock)
            switch self.state {
            case .setup(let downstream, let closure, let subject, let demand):
                self.state = .active(upstream: subscription, downstream: downstream, setup: (demand > 0) ? nil : (closure, subject))
                os_unfair_lock_unlock(&self.lock)
                subscription.request(demand)
                guard demand > 0 else { return }
                subscription.request(demand)
                closure(subject)
            case .cancelled:
                os_unfair_lock_unlock(&self.lock)
            case .inactive, .active: fatalError()
            }
        }
        
        // Stage 3: Receive input from the `Passthrough` subject.
        func receive(_ input: Output) -> Subscribers.Demand {
            os_unfair_lock_lock(&self.lock)
            let downstream = self.state.downstream
            os_unfair_lock_unlock(&self.lock)
            return downstream?.receive(input) ?? .none
        }
        
        // Stage 4: Receive completion from the `Passthrough` subject.
        func receive(completion: Subscribers.Completion<Failure>) {
            os_unfair_lock_lock(&self.lock)
            let downstream = self.state.downstream
            self.state = .cancelled
            os_unfair_lock_unlock(&self.lock)
            downstream?.receive(completion: completion)
        }
        
        func cancel() {
            os_unfair_lock_lock(&self.lock)
            let upstream = self.state.upstream
            self.state = .cancelled
            os_unfair_lock_unlock(&self.lock)
            upstream?.cancel()
        }
        
        /// The state in which the `Conduit` subscription finds itself in.
        private enum State {
            typealias SetUp = (closure: Closure, subject: PassthroughSubject<Output,Failure>)
            /// The subscription has been initialized and sent downstream (as if the `Conduit` was the origin of the shadow subscription chain.
            case inactive(downstream: Downstream, closure: Closure)
            /// A greater than zero demand has been requested and thus the subject has been created and subscribed to. Now `Conduit` is waiting to receive an acknowledgment from the subject.
            case setup(downstream: Downstream, closure: Closure, subject: PassthroughSubject<Output,Failure>, demand: Subscribers.Demand)
            /// The subject has acknowledge creation and the full chain is setup and working. Demand is being forwarded directly to the subject subscription.
            case active(upstream: Subscription, downstream: Downstream, setup: SetUp?)
            /// The chain has been destroyed and no references are kept.
            case cancelled
            /// Returns the downstream subscription (if any).
            var downstream: Downstream? {
                switch self {
                case .inactive(let downstream, _): return downstream
                case .setup(let downstream, _, _, _): return downstream
                case .active(_, let downstream, _): return downstream
                case .cancelled: return nil
                }
            }
            /// Returns the upstream subscription (if any).
            var upstream: Subscription? {
                switch self {
                case .active(let upstream, _, _): return upstream
                case .inactive, .setup, .cancelled: return nil
                }
            }
        }
    }
}
