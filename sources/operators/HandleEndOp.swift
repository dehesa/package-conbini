import Combine

extension Publisher {
    /// Performs the specified closure when the publisher completes (whether successfully or with a failure) or when the publisher gets cancelled.
    ///
    /// The closure will get executed exactly once.
    /// - parameter handle: A closure that executes when the publisher receives a completion event or when the publisher gets cancelled.
    /// - parameter completion: A completion event if the publisher completes (whether successfully or not), or `nil` in case the publisher is cancelled.
    @inlinable public func handleEnd(_ handle: @escaping (_ completion: Subscribers.Completion<Failure>?)->Void) -> Publishers.HandleEnd<Self> {
        .init(upstream: self, handle: handle)
    }
}
