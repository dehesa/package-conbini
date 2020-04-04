import Combine
import Foundation

extension Publisher {
    /// Attempts to recreate a failed subscription with the upstream publisher using a specified number of attempts to establish the connection and a given amount of seconds between attempts.
    /// - parameter scheduler: The scheduler used to wait for the specific intervals.
    /// - parameter tolerance: The tolerance used when scheduling a new attempt after a failure. A default implies the minimum tolerance.
    /// - parameter options: The options for the given scheduler.
    /// - parameter intervals: The amount of seconds to wait after a failure occurrence. Negative values are considered zero.
    /// - returns: A publisher that attemps to recreate its subscription to a failed upstream publisher a given amount of times and waiting a given amount of seconds between attemps.
    @inlinable public func retry<S>(on scheduler: S, tolerance: S.SchedulerTimeType.Stride? = nil, options: S.SchedulerOptions? = nil, intervals: [TimeInterval]) -> Publishers.DelayedRetry<Self,S> where S:Scheduler {
        .init(upstream: self, scheduler: scheduler, options: options, intervals: intervals)
    }
}
