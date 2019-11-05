import Combine
import Foundation

extension Publishers {
    /// Executes child publishers one at a time through the use of backpressure management.
    ///
    /// If the upstream emits values without regard to backpressure (e.g. Subjects), `SequentialFlatMap` buffers them internally; however if a completion event is sent, the values in the buffer won't be executed. To have truly sequential event handling on non-supporting backpressure upstreams, use the buffer operator.
    /// ```
    /// let upstream = PassthroughSubject<Int,CustomError>()
    /// let downstream = upstream
    ///     .buffer(size: 100, prefetch: .keepFull, whenFull: .customError(CustomError())
    ///     .sequentialFlatMap()
    /// upstream.send(publisherA)
    /// upstream.send(publisherB)
    /// upstream.send(publisherC)
    /// ```
    /// Buffer isn't necessary for any operator that has support for backpressure (e.g. `Publishers.Sequence`).
    /// ```
    /// let upstream = [
    ///     firstCallToEndpointPublisher,
    ///     secondCallToEndpointPublisher,
    ///     thirdCallToEndpointPublisher
    /// ].publisher
    /// let downstream = upstream.sequentialFlatMap()
    /// ```
    /// - attention: The stream only completes when both the upstream and the children publishers complete.
    public struct SequentialFlatMap<Child,Upstream,Failure>: Publisher where Child:Publisher, Upstream:Publisher, Failure:Swift.Error, Upstream.Output==Child {
        public typealias Output = Child.Output
        
        /// The publisher from which this publisher receives children.
        public let upstream: Upstream
        
        /// Designated initializer passing the publisher emitting values received here.
        /// - parameter upstream: The publisher from which this publisher receives children.
        internal init(upstream: Upstream, failure: Failure.Type) {
            self.upstream = upstream
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let subscriber = UpstreamSubscriber(downstream: subscriber)
            upstream.subscribe(subscriber)
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscription representing the `SequentialFlatMap` publisher.
    fileprivate final class Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Performant non-rentrant unfair lock.
        var lock: UnsafeMutablePointer<os_unfair_lock>
        /// The state managing the upstream and children subscriptions.
        var state: State
        
        /// Designated initializer passing the downstream subscriber.
        /// - parameter downstream: The `Subscriber` receiving the outcome of this *described* publisher.
        init(downstream: Downstream) {
            self.lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
            self.lock.initialize(to: os_unfair_lock())
            self.state = .awaitingSubscription(downstream: downstream)
        }
        
        deinit {
            self.cancel()
            self.lock.deallocate()
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            os_unfair_lock_lock(self.lock)
            guard let config = self.state.configuration else {
                return os_unfair_lock_unlock(self.lock)
            }
            config.demand += demand
            
            var action: Either<Subscription,Child>? = nil
            switch config.childState {
            case .active(let childStream):
                action = .left(childStream)
                config.demand -= 1
            case .idle where config.waitingPublishers.isEmpty:
                action = config.upstream.map { .left($0) }
            case .idle:
                action = .right(config.waitingPublishers.removeFirst())
                config.childState = .awaitingSubscription
            case .awaitingSubscription: break
            }
            os_unfair_lock_unlock(self.lock)

            switch action {
            case .left(let subscription): subscription.request(.max(1))
            case .right(let publisher): publisher.subscribe(ChildSubscriber(conduit: self))
            case .none: break
            }
        }
        
        func cancel() {
            os_unfair_lock_lock(self.lock)
            let state = self.state
            self.state = .terminated
            os_unfair_lock_unlock(self.lock)
            
            guard case .active(let configuration) = state else { return }
            configuration.childState.subscription?.cancel()
            configuration.upstream?.cancel()
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscriber sent upstream to receive its inputs and completion events.
    private struct UpstreamSubscriber<Downstream>: Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Strong bond to the `Conduit` instance, so it is kept alive between upstream subscription and the subscription acknowledgement.
        let conduit: Conduit<Downstream>
        
        /// Designated initializer for this helper establishing the strong bond between the `Conduit` and the created helper.
        init(downstream: Downstream) {
            self.conduit = .init(downstream: downstream)
        }
        
        var combineIdentifier: CombineIdentifier {
            self.conduit.combineIdentifier
        }
        
        func receive(subscription: Subscription) {
            os_unfair_lock_lock(self.conduit.lock)
            switch self.conduit.state {
            case .awaitingSubscription(let downstream):
                self.conduit.state = .active(.init(upstream: subscription, downstream: downstream))
                os_unfair_lock_unlock(self.conduit.lock)
                downstream.receive(subscription: self.conduit)
            case .terminated: os_unfair_lock_unlock(self.conduit.lock)
            case .active: fatalError("Combine assures a second subscription won't be ever received")
            }
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            os_unfair_lock_lock(self.conduit.lock)
            guard let config = self.conduit.state.configuration else {
                os_unfair_lock_unlock(self.conduit.lock)
                return .none
            }
            
            config.waitingPublishers.append(input)
            guard case .idle = config.childState, config.demand > 0 else {
                os_unfair_lock_unlock(self.conduit.lock)
                return .none
            }
            
            let child = config.waitingPublishers.removeFirst()
            config.childState = .awaitingSubscription
            os_unfair_lock_unlock(self.conduit.lock)
            
            child.subscribe(ChildSubscriber(conduit: self.conduit))
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            os_unfair_lock_lock(self.conduit.lock)
            guard let config = self.conduit.state.configuration else {
                return os_unfair_lock_unlock(self.conduit.lock)
            }
            
            switch completion {
            case .failure(let upstreamError):
                self.conduit.state = .terminated
                os_unfair_lock_unlock(self.conduit.lock)
                config.childState.subscription?.cancel()
                config.downstream.receive(completion: .failure(upstreamError as! Downstream.Failure))
            case .finished:
                if config.waitingPublishers.isEmpty, case .idle = config.childState {
                    self.conduit.state = .terminated
                    os_unfair_lock_unlock(self.conduit.lock)
                    config.downstream.receive(completion: .finished)
                } else {
                    config.upstream = nil
                    os_unfair_lock_unlock(self.conduit.lock)
                }
            }
        }
    }
}

extension Publishers.SequentialFlatMap {
    /// Subscriber receiving the children inputs and completion events.
    private struct ChildSubscriber<Downstream>: Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Strong bond to the `Conduit` instance, so it is kept alive between subscription and the subscription acknowledgement.
        let conduit: Conduit<Downstream>
        
        /// Designated initializer for this helper establishing the strong bond between the `Conduit` and the created helper.
        init(conduit: Conduit<Downstream>) {
            self.conduit = conduit
        }
        
        var combineIdentifier: CombineIdentifier {
            self.conduit.combineIdentifier
        }
        
        func receive(subscription: Subscription) {
            os_unfair_lock_lock(self.conduit.lock)
            guard let config = self.conduit.state.configuration else {
                return os_unfair_lock_unlock(self.conduit.lock)
            }
            
            guard case .awaitingSubscription = config.childState else {
                fatalError()
            }
            
            config.childState = .active(child: subscription)
            guard config.demand > 0 else {
                return os_unfair_lock_unlock(self.conduit.lock)
            }
            config.demand -= 1
            os_unfair_lock_unlock(self.conduit.lock)
            subscription.request(.max(1))
        }
        
        func receive(_ input: Child.Output) -> Subscribers.Demand {
            os_unfair_lock_lock(self.conduit.lock)
            guard let c = self.conduit.state.configuration,
                  case .active = c.childState else {
                os_unfair_lock_unlock(self.conduit.lock)
                return .none
            }
            
            let downstream = c.downstream
            os_unfair_lock_unlock(self.conduit.lock)
            let receivedDemand = downstream.receive(input)
            
            os_unfair_lock_lock(self.conduit.lock)
            guard case .active(let config) = self.conduit.state,
                  case .active = config.childState else {
                os_unfair_lock_unlock(self.conduit.lock)
                return .none
            }
            
            config.demand += receivedDemand
            guard config.demand > 0 else {
                os_unfair_lock_unlock(self.conduit.lock)
                return .none
            }
            
            config.demand -= 1
            os_unfair_lock_unlock(self.conduit.lock)
            return .max(1)
        }
        
        func receive(completion: Subscribers.Completion<Child.Failure>) {
            os_unfair_lock_lock(self.conduit.lock)
            guard let config = self.conduit.state.configuration else {
                return os_unfair_lock_unlock(self.conduit.lock)
            }
            
            switch completion {
            case .failure(let error):
                self.conduit.state = .terminated
                os_unfair_lock_unlock(self.conduit.lock)
                config.downstream.receive(completion: .failure(error as! Downstream.Failure))
            case .finished:
                if !config.waitingPublishers.isEmpty {
                    config.childState = .awaitingSubscription
                    let publisher = config.waitingPublishers.removeFirst()
                    os_unfair_lock_unlock(self.conduit.lock)
                    publisher.subscribe(ChildSubscriber(conduit: self.conduit))
                } else if let upstream = config.upstream {
                    config.childState = .idle
                    os_unfair_lock_unlock(self.conduit.lock)
                    upstream.request(.max(1))
                } else {
                    self.conduit.state = .terminated
                    os_unfair_lock_unlock(self.conduit.lock)
                    config.downstream.receive(completion: .finished)
                }
            }
        }
    }
}

extension Publishers.SequentialFlatMap.Conduit {
    /// The state managing the upstream and children subscriptions.
    fileprivate enum State {
        /// The `Conduit` has been initialized, but it is not yet connected to the upstream.
        case awaitingSubscription(downstream: Downstream)
        /// The `Conduit` is connected to the upstream and it is receiving events.
        case active(Configuration)
        /// The `Conduit` has been cancelled, or it has been terminated (whether successfully or not).
        case terminated
        
        /// - warning: This property crashes for states `.awaitingSubscription`
        var configuration: Configuration? {
            switch self {
            case .active(let config): return config
            case .terminated: return nil
            case .awaitingSubscription: fatalError()
            }
        }
    }
}

extension Publishers.SequentialFlatMap.Conduit {
    /// Holds information necessary to manage the `SequentialFlatMap` subscription once it has been activated.
    final class Configuration {
        /// The subscription used to manage the upstream back-pressure.
        var upstream: Subscription?
        /// The subscriber receiving the input and completion.
        let downstream: Downstream
        /// The child state managing the sequential children.
        var childState: ChildState
        /// The children that has been sent but not yet executed.
        var waitingPublishers: [Child]
        /// The demand requested by the downstream so far.
        var demand: Subscribers.Demand
        /// Designated initializer providing the required upstream and downstream. All other information is set with the defaults.
        init(upstream: Subscription, downstream: Downstream) {
            self.upstream = upstream
            self.downstream = downstream
            self.childState = .idle
            self.waitingPublishers = []
            self.demand = .none
        }
    }
}

/// The state managing the children subscriptions (exclusively).
private enum ChildState {
    /// There is no child expected or active at the moment.
    case idle
    /// A subscription to a child publisher has been set, but no acknoledgement has been yet received.
    case awaitingSubscription
    /// The child publisher is active and emitting values.
    case active(child: Subscription)
    
    /// Returns a child subscription if there is a child currently active.
    var subscription: Subscription? {
        guard case .active(let child) = self else { return nil }
        return child
    }
    
    /// Boolean indicating whether the child is currently on "running mode".
    var isActive: Bool {
        guard case .active = self else { return false }
        return true
    }
}
