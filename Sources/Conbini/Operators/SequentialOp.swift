import Combine

extension Publisher {
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// Please note:
    /// - Values are processed one at a time; meaning till the previous value has not been fully processed, the next won't start.
    /// - `Promise` must be called with the transformed value or the stream will never complete.
    /// ```
    /// [0, 1, 2].publisher.sequentialContinuousMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        // Some operation with value
    ///        promise( String(value) )
    ///    }
    /// }
    /// ```
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    public func asyncMap<T>(_ transform: @escaping Publishers.SequentialMap<Self,T>.SimpleClosure) -> Publishers.SequentialMap<Self,T> {
        .init(upstream: self) { (value, promise) in
            transform(value) { (result) in
                _ = promise(result, .finished)
            }
        }
    }
    
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// The `SequentialMap` publisher transform upstream values (one at a time) allowing the transformation result to be called later on. Also, for each value received the `transform` closure may output several downstream values. Please note:
    /// - Values are processed one at a time; meaning till the previous value has not been fully processed, the next won't start.
    ///   This might be potentially dangerous if the previous value never completes.
    /// - `Promise` accepts the transformed result and a value indicating whether the closure is willing to keep sending values.
    /// ```
    /// [0, 1, 2].publisher.sequentialContinuousMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        // Some operation with value
    ///        promise( String(value) )
    ///    }
    /// }
    /// ```
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    public func sequentialMap<T>(_ transform: @escaping Publishers.SequentialMap<Self,T>.Closure) -> Publishers.SequentialMap<Self,T> {
        .init(upstream: self, transform: transform)
    }
}

extension Publisher where Output:Publisher {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
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
    /// - attention: Any error emitted by the upstream or any of the child publishers is forwarded immediately downstream, effectively shutting down this stream. Also, this stream only successfully completes when both the upstream and the children publishers complete.
    /// - returns: A publisher executing the received value publishers one at a time.
    public func sequentialFlatMap() -> Publishers.SequentialFlatMap<Output,Self,Swift.Error> {
        .init(upstream: self, failure: Swift.Error.self)
    }
    
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
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
    /// - attention: Any error emitted by the upstream or any of the child publishers is forwarded immediately downstream, effectively shutting down this stream. Also, this stream only successfully completes when both the upstream and the children publishers complete.
    /// - parameter failure: The type of error output from this publisher. Any error received from upstream or child streams will be force cast to this type.It is useful when either the upstream or the child stream never fails, so you can forward a typed error instead of a `Swift.Error`.
    /// - returns: A publisher executing the received value publishers one at a time.
    public func sequentialFlatMap<Error>(failure: Error.Type) -> Publishers.SequentialFlatMap<Output,Self,Error> {
        .init(upstream: self, failure: Error.self)
    }
}
