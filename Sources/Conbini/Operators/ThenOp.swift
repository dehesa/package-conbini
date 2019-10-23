import Combine

extension Publisher {
    /// Ignores all value events and on successful completion it transform that into a give `Downstream` publisher.
    ///
    /// The `downstream` closure will only be executed once the successful completion event arrives. If it doesn't arrive, it is never executed.
    /// - parameter transform: Closure generating the stream to be switched to once a completion event is received from upstream.
    public func then<Child>(_ transform: @escaping ()->Child) -> Publishers.Then<Child,Self> where Child:Publisher, Self.Failure==Child.Failure {
        .init(upstream: self, transform: transform)
    }
}
