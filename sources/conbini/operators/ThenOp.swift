import Combine

extension Publisher {
    /// Ignores all upstream value events and when it completes successfully, the operator switches to the provided publisher.
    ///
    /// The `transform` closure will only be executed once the successful completion event arrives. If it doesn't arrive, it is never executed.
    /// - parameter maxDemand: The maximum demand requested to the upstream at the same time.
    /// - parameter transform: Closure generating the stream to be switched to once a successful completion event is received from upstream.
    @inlinable public func then<Child>(maxDemand: Subscribers.Demand = .unlimited, _ transform: @escaping ()->Child) -> Publishers.Then<Child,Self> where Child:Publisher, Self.Failure==Child.Failure {
        Publishers.Then(upstream: self, maxDemand: maxDemand, transform: transform)
    }
}
