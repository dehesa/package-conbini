import Combine

extension Publisher {
    /// Transforms all elements from the upstream publisher with a provided closure, giving the option to send several ouput values from the closure.
    ///
    /// The publisher will only complete if the upstream has completed and all the value transformation have returned at some point `promise(transformedValue, .finished)`.
    ///
    /// Also, it is worth noticing that `promise`s return a `Permission` enum value indicating whether the subscriber wants to receive more values.
    /// ```
    /// [1, 10, 100].publisher.asyncMap { (value, isCancelled, promise) in
    ///    queue.asyncAfter(deadline: ...) {
    ///        guard !isCancelled else { return }
    ///
    ///        promise(String(value), .continue)
    ///        promise(String(value*2), .continue)
    ///        promise(String(value*4), .finished)
    ///    }
    /// }
    /// ```
    /// - parameter parallel: The maximum number of values being processed at a time. Since the processing is returned in a promise, many upstream values can be processed at a single time point.
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - returns: A publisher with output `T` and failure `Upstream.Failure`.
    public func asyncMap<T>(parallel: Subscribers.Demand, _ transform: @escaping Publishers.AsyncMap<Self,T>.Closure) -> Publishers.AsyncMap<Self,T> {
        .init(upstream: self, parallel: parallel, transform: transform)
    }
    
    /// Transforms all elements from the upstream publisher with a provided a closure, giving the option to send several output values or an error (through the `Result` type) from the closure.
    ///
    /// The publisher will only complete if the upstream has completed and all the value transformation have returned at some point `promise(transformedValue, .finished)`.
    ///
    /// Also, it is worth noticing that `promise`s return a `Permission` enum value indicating whether the subscriber wants to receive more values.
    /// ```
    /// [0, 1, 2].publisher.asyncTryMap { (value, isCancelled, promise) in
    ///    queue.async {
    ///        promise(.success((value * 2, .continue)))
    ///        promise(.success((value * 4, .continue)))
    ///        promise(.failure(error))
    ///    }
    /// }
    /// ```
    /// - parameter parallel: The maximum number of values being processed at a time. Since the processing is returned in a promise, many upstream values can be processed at a single time point.
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - returns: A publisher with output `T` and failure `Swift.Error`.
    public func asyncTryMap<T>(parallel: Subscribers.Demand, _ transform: @escaping Publishers.AsyncTryMap<Self,T>.Closure) -> Publishers.AsyncTryMap<Self,T> {
        .init(upstream: self, parallel: parallel, transform: transform)
    }
}
