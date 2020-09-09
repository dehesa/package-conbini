import Combine
import Foundation

extension Publishers {
    /// A publisher that attempts to recreate its subscription to a failed upstream publisher waiting a given time interval between retries.
    ///
    /// Please notice that any value sent before a failure is still received downstream.
    public struct DelayedRetry<Upstream,S>: Publisher where Upstream:Publisher, S:Scheduler {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        /// The upstream publisher.
        public let upstream: Upstream
        /// The scheduler used to wait for a specific time interval.
        public let scheduler: S
        /// The tolerance used when scheduling a new attempt after a failure. A default implies the minimum tolerance.
        public let tolerance: S.SchedulerTimeType.Stride?
        /// The options for the specified scheduler.
        public let options: S.SchedulerOptions?
        /// The amount of seconds being waited after a failure occurrence. Negative values are considered zero.
        public let intervals: [TimeInterval]
        /// Creates a publisher that transforms the incoming value into another value, but may respond at a time in the future.
        /// - parameter upstream: The event emitter to the publisher being created.
        /// - parameter scheduler: The scheduler used to wait for the specific intervals.
        /// - parameter options: The options for the given scheduler.
        /// - parameter intervals: The amount of seconds to wait after a failure occurrence. Negative values are considered zero.
        @inlinable public init(upstream: Upstream, scheduler: S, tolerance: S.SchedulerTimeType.Stride? = nil, options: S.SchedulerOptions? = nil, intervals: [TimeInterval]) {
            self.upstream = upstream
            self.scheduler = scheduler
            self.tolerance = tolerance
            self.options = options
            self.intervals = intervals
        }
        
        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let conduit = DelayedRetry.Conduit(upstream: self.upstream, downstream: subscriber,
                                               scheduler: self.scheduler, tolerance: self.tolerance, options: self.options,
                                               intervals: self.intervals)
            self.upstream.subscribe(conduit)
        }
    }
}

fileprivate extension Publishers.DelayedRetry {
    /// Represents an active `DelayedRetry` publisher taking both the role of `Subscriber` (for upstream publishers) and `Subscription` (for downstream subscribers).
    final class Conduit<Downstream>: Subscription, Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        /// Enum listing all possible conduit states.
        @Lock private var state: State<_WaitConfiguration,_ActiveConfiguration>
        
        init(upstream: Upstream, downstream: Downstream, scheduler: S, tolerance: S.SchedulerTimeType.Stride?, options: S.SchedulerOptions?, intervals: [TimeInterval]) {
            self.state = .awaitingSubscription(
                .init(publisher: upstream, downstream: downstream,
                      scheduler: scheduler, tolerance: tolerance, options: options,
                      intervals: intervals, next: 0, demand: .none)
            )
        }
        
        deinit {
            self.cancel()
            self._state.invalidate()
        }
        
        func receive(subscription: Subscription) {
            guard let config = self._state.activate(atomic: { .init(upstream: subscription, config: $0) }) else {
                return subscription.cancel()
            }
            
            switch config.isPrime {
            case true:  config.downstream.receive(subscription: self)
            case false: config.upstream.request(config.demand)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            self._state.lock()
            
            switch self._state.value {
            case .awaitingSubscription(let config):
                guard !config.isPrime else { fatalError("A request cannot happen before a subscription has been performed") }
                config.demand += demand
                self._state.unlock()
            case .active(let config):
                config.demand += demand
                self._state.unlock()
                config.upstream.request(demand)
            case .terminated:
                self._state.unlock()
            }
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            self._state.lock()
            guard let config1 = self._state.value.activeConfiguration else {
                self._state.unlock()
                return .none
            }
            
            config1.demand -= 1
            let downstream = config1.downstream
            self._state.unlock()
            
            let demand = downstream.receive(input)
            self._state.lock()
            guard let config2 = self._state.value.activeConfiguration else {
                self._state.unlock()
                return .none
            }
            
            config2.demand += demand
            self._state.unlock()
            return demand
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            self._state.lock()
            guard let activeConfig = self._state.value.activeConfiguration else {
                return self._state.unlock()
            }
            
            guard case .failure = completion, let pause = activeConfig.nextPause else {
                let downstream = activeConfig.downstream
                self._state.value = .terminated
                self._state.unlock()
                return downstream.receive(completion: completion)
            }
            
            self._state.value = .awaitingSubscription(.init(config: activeConfig))
            
            guard pause > 0 else {
                let publisher = activeConfig.publisher
                self._state.unlock()
                return publisher.subscribe(self)
            }

            let config = _WaitConfiguration(config: activeConfig)
            let (scheduler, tolerance, options) = (config.scheduler, config.tolerance ?? config.scheduler.minimumTolerance, config.options)
            self._state.unlock()
            
            let date = scheduler.now.advanced(by: .seconds(pause))
            scheduler.schedule(after: date, tolerance: tolerance, options: options) { [weak self] in
                guard let self = self else { return }
                self._state.lock()
                guard let config = self._state.value.awaitingConfiguration else { return self._state.unlock() }
                let publisher = config.publisher
                self._state.unlock()
                publisher.subscribe(self)
            }
        }
        
        func cancel() {
            guard case .active(let config) = self._state.terminate() else { return }
            config.upstream.cancel()
        }
    }
}

private extension Publishers.DelayedRetry.Conduit {
    /// The necessary variables during the *awaiting* stage.
    final class _WaitConfiguration {
        /// The publisher to be initialized in case of problems.
        let publisher: Upstream
        /// The subscriber further down the chain.
        let downstream: Downstream
        /// The scheduler used to wait for the specific intervals.
        let scheduler: S
        /// The tolerance used when scheduling a new attempt after a failure. A default implies the minimum tolerance.
        let tolerance: S.SchedulerTimeType.Stride?
        /// The options for the given scheduler.
        let options: S.SchedulerOptions?
        /// The amount of seconds to wait after a failure occurrence.
        let intervals: [TimeInterval]
        /// The interval to use next if a failure is received.
        var next: Int
        /// The downstream requested demand.
        var demand: Subscribers.Demand
        
        /// Boolean indicating whether the conduit has ever been subscribed to or not.
        var isPrime: Bool {
            return self.next == 0
        }
        
        /// Designated initializer.
        init(publisher: Upstream, downstream: Downstream, scheduler: S, tolerance: S.SchedulerTimeType.Stride?, options: S.SchedulerOptions?, intervals: [TimeInterval], next: Int, demand: Subscribers.Demand) {
            precondition(next >= 0)
            self.publisher = publisher
            self.downstream = downstream
            self.scheduler = scheduler
            self.tolerance = tolerance
            self.options = options
            self.intervals = intervals
            self.next = next
            self.demand = demand
        }
        
        convenience init(config: _ActiveConfiguration) {
            self.init(publisher: config.publisher, downstream: config.downstream,
                      scheduler: config.scheduler, tolerance: config.tolerance, options: config.options,
                      intervals: config.intervals, next: config.next, demand: config.demand)
        }
    }
    
    /// The necessary variables during the *active* stage.
    final class _ActiveConfiguration {
        /// The publisher to be initialized in case of problems.
        let publisher: Upstream
        /// The upstream subscription.
        let upstream: Subscription
        /// The subscriber further down the chain.
        let downstream: Downstream
        /// The scheduler used to wait for the specific intervals.
        let scheduler: S
        /// The tolerance used when scheduling a new attempt after a failure. A default implies the minimum tolerance.
        let tolerance: S.SchedulerTimeType.Stride?
        /// The options for the given scheduler.
        let options: S.SchedulerOptions?
        /// The amount of seconds to wait after a failure occurrence.
        let intervals: [TimeInterval]
        /// The interval to use next if a failure is received.
        var next: Int
        /// The downstream requested demand.
        var demand: Subscribers.Demand
        
        /// Boolean indicating whether it is the first ever attemp (primal attempt).
        var isPrime: Bool {
            return self.next == 0
        }
        
        /// Produces the next pause and increments the index integer.
        var nextPause: TimeInterval? {
            guard self.next < self.intervals.endIndex else { return nil }
            let pause = self.intervals[self.next]
            self.next += 1
            return pause
        }
        
        /// Designated initializer.
        init(publisher: Upstream, upstream: Subscription, downstream: Downstream, scheduler: S, tolerance: S.SchedulerTimeType.Stride?, options: S.SchedulerOptions?, intervals: [TimeInterval], next: Int, demand: Subscribers.Demand) {
            precondition(next >= 0)
            self.publisher = publisher
            self.upstream = upstream
            self.downstream = downstream
            self.scheduler = scheduler
            self.tolerance = tolerance
            self.options = options
            self.intervals = intervals
            self.next = next
            self.demand = demand
        }
        
        convenience init(upstream: Subscription, config: _WaitConfiguration) {
            self.init(publisher: config.publisher, upstream: upstream, downstream: config.downstream,
                      scheduler: config.scheduler, tolerance: config.tolerance, options: config.options,
                      intervals: config.intervals, next: config.next, demand: config.demand)
        }
    }
}
