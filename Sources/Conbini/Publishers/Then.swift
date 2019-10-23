import Combine
import Foundation

extension Publishers {
    /// Transform the upstream successful completion event into a new or existing publisher.
    public struct Then<Child,Upstream>: Publisher where Upstream:Publisher, Child:Publisher, Upstream.Failure==Child.Failure {
        public typealias Output = Child.Output
        public typealias Failure = Child.Failure
        
        /// Publisher emitting the events being received here.
        public let upstream: Upstream
        /// Closure that will crete the publisher that will emit events downstream once a successful completion is received.
        public let transform: () -> Child
        /// Designated initializer providing the upstream publisher and the closure in charge of arranging the transformation.
        /// - parameter upstream: Upstream publisher chain which successful completion will trigger the `transform` closure.
        /// - parameter transfom: Closure providing the new (or existing) publisher.
        public init(upstream: Upstream, transform: @escaping ()->Child) {
            self.upstream = upstream
            self.transform = transform
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, Output==S.Input, Failure==S.Failure {
            let subscriber = Conduit.make(downstream: subscriber, transform: self.transform)
            upstream.subscribe(subscriber)
        }
    }
}

extension Publishers.Then {
    /// Represents an active `Then` publisher taking both the role of `Subscriber` (for upstream publishers) and `Subscription` (for downstream subscribers).
    ///
    /// This subscriber takes as inputs any value provided from upstream, but ignores them. Only when a successful completion has been received, a `Child` publisher will get generated.
    /// The child events will get emitted as-is (i.e. without any modification).
    fileprivate final class Conduit<Downstream>: Subscription, Subscriber where Downstream: Subscriber, Downstream.Input==Child.Output, Downstream.Failure==Child.Failure {
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure
        
        /// Performant non-rentrant unfair lock.
        private var lock: os_unfair_lock
        /// Keeps track of the subscription state
        private var state: State
        
        /// Designated initializer holding the downstream subscribers.
        /// - parameter downstream: The subscriber receiving values downstream.
        /// - parameter transform: The closure that will eventually generate another publisher to switch to.
        private init(downstream: Downstream, transform: @escaping ()->Child) {
            self.lock = .init()
            self.state = .initialized(closure: transform, downstream: downstream)
        }
        
        /// Creates a strong bond between the upstream `Subscriber` returned and the created `Conduit`.
        /// - parameter downstream: The subscriber receiving values downstream.
        /// - parameter transform: The closure that will eventually generate another publisher to switch to.
        static func make(downstream: Downstream, transform: @escaping ()->Child) -> UpstreamSubscriber {
            let conduit = Conduit(downstream: downstream, transform: transform)
            return UpstreamSubscriber(conduit: conduit)
        }
        
        func receive(subscription: Subscription) {
            os_unfair_lock_lock(&self.lock)
            
            switch self.state {
            case .initialized(let closure, let downstream):
                self.state = .upstreaming(subscription: subscription, closure: closure, downstream: downstream, downstreamRequests: .none)
                os_unfair_lock_unlock(&self.lock)
                downstream.receive(subscription: self)
            case .upstreaming(_, _, let downstream, let downstreamRequests):
                self.state = .transformed(subscription: subscription, downstream: downstream)
                os_unfair_lock_unlock(&self.lock)
                subscription.request(downstreamRequests)
            case .transformed: fatalError()
            case .terminated: os_unfair_lock_unlock(&self.lock)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }

            let request: (Subscription, Subscribers.Demand)?

            os_unfair_lock_lock(&self.lock)
            switch self.state {
            case .initialized: fatalError()
            case .upstreaming(let s, let c, let d, let r):
                self.state = .upstreaming(subscription: s, closure: c, downstream: d, downstreamRequests: r + demand)
                request = (r == .none) ? (s, .unlimited) : nil
            case .transformed(let s, _): request = (s, demand)
            case .terminated: request = nil
            }
            os_unfair_lock_unlock(&self.lock)

            guard let (subscription, demand) = request else { return }
            subscription.request(demand)
        }
        
        func receiveUpstream(completion: Subscribers.Completion<Upstream.Failure>) {
            os_unfair_lock_lock(&self.lock)
            guard case .upstreaming(_, let closure, let downstream, _) = self.state else {
                return os_unfair_lock_unlock(&self.lock)
            }
            
            switch completion {
            case .failure:
                self.state = .terminated
                os_unfair_lock_unlock(&self.lock)
                downstream.receive(completion: completion)
            case .finished:
                os_unfair_lock_unlock(&self.lock)
                let child = closure()
                child.subscribe(self)
            }
        }
        
        // receiveChild(_ input:)
        func receive(_ input: Downstream.Input) -> Subscribers.Demand {
            os_unfair_lock_lock(&self.lock)
            switch self.state {
            case .initialized, .upstreaming:
                fatalError()
            case .transformed(_, let downstream):
                os_unfair_lock_unlock(&self.lock)
                return downstream.receive(input)
            case .terminated:
                os_unfair_lock_unlock(&self.lock)
                return .none
            }
        }
        
        // receiveChild(completion:)
        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            os_unfair_lock_lock(&self.lock)
            switch self.state {
            case .initialized, .upstreaming:
                fatalError()
            case .transformed(_, let downstream):
                self.state = .terminated
                os_unfair_lock_unlock(&self.lock)
                downstream.receive(completion: completion)
            case .terminated:
                os_unfair_lock_unlock(&self.lock)
            }
        }

        func cancel() {
            os_unfair_lock_lock(&self.lock)
            let subscription = self.state.subscription
            self.state = .terminated
            os_unfair_lock_unlock(&self.lock)
            subscription?.cancel()
        }
        
        deinit {
            self.cancel()
        }
    }
}

extension Publishers.Then.Conduit {
    /// Helper that acts as a `Subscriber` for the upstream, but just forward events to the given `Conduit` instance.
    fileprivate struct UpstreamSubscriber: Subscriber {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        /// Strong bond to the `Conduit` instance, so it is kept alive between upstream subscription and the subscription acknowledgement.
        let conduit: Publishers.Then<Child,Upstream>.Conduit<Downstream>
        
        /// Designated initializer for this helper establishing the strong bond between the `Conduit` and the created helper.
        init(conduit: Publishers.Then<Child,Upstream>.Conduit<Downstream>) {
            self.conduit = conduit
        }
        
        var combineIdentifier: CombineIdentifier {
            self.conduit.combineIdentifier
        }
        
        func receive(subscription: Subscription) {
            self.conduit.receive(subscription: subscription)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            .unlimited
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            self.conduit.receiveUpstream(completion: completion)
        }
    }
}

extension Publishers.Then.Conduit {
    /// The states the `Then`'s `Conduit` cycles through.
    fileprivate enum State {
        /// The `Conduit` has been initialized, but it is not yet connected to the upstream.
        case initialized(closure: ()->Child, downstream: Downstream)
        /// The `Conduit` is connected to the upstream and receiving its events.
        case upstreaming(subscription: Subscription, closure: ()->Child, downstream: Downstream, downstreamRequests: Subscribers.Demand)
        /// The `Conduit` has already received a successful completion from the upstream and has switched to the `Child` publisher.
        case transformed(subscription: Subscription, downstream: Downstream)
        /// The `Conduit` has been cancelled, or has received a failure termination, or its `Child` has successfully terminated.
        case terminated
        
        /// Returns the upstream or child `Subscription` to request more data.
        var subscription: Subscription? {
            switch self {
            case .initialized: return nil
            case .upstreaming(let s, _, _, _): return s
            case .transformed(let s, _): return s
            case .terminated: return nil
            }
        }
    }
}

