import Combine

// MARK: Never / Never -> Never

extension Publisher where Output:Publisher, Failure==Never, Output.Failure==Never {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
    ///
    /// The `SequentialFlatMap` doesn't buffer the incoming publishers; instead it controls the demand only asking a new publisher when it needs it (i.e. sequentially).
    /// If you use a `Subject` to send a barrage of publishers, they will be ignored except the first one. If you want to received all publishers, you would need to add a `buffer` operator before this `sequentialFlatMap`; such as:
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
    /// - attention: The generated publisher doesn't forward any failure and the stream only completes when both the upstream and the children publishers complete.
    /// - returns: A publisher executing the received value publishers one at a time.
    public func sequentialFlatMap() -> Publishers.SequentialFlatMap<Output,Self,Never> {
        .init(upstream: self, failure: Never.self)
    }
}

// MARK: Never / CustomError -> CustomError

extension Publisher where Output:Publisher, Failure==Never {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
    ///
    /// The `SequentialFlatMap` doesn't buffer the incoming publishers; instead it controls the demand only asking a new publisher when it needs it (i.e. sequentially).
    /// If you use a `Subject` to send a barrage of publishers, they will be ignored except the first one. If you want to received all publishers, you would need to add a `buffer` operator before this `sequentialFlatMap`; such as:
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
    /// - attention: Any error emitted by a child publisher is forwarded immediately downstream, effectively shutting down this stream. Also, this stream only successfully completes when both the upstream and the children publishers complete.
    /// - returns: A publisher executing the received value publishers one at a time.
    public func sequentialFlatMap() -> Publishers.SequentialFlatMap<Output,Self,Output.Failure> {
        .init(upstream: self, failure: Output.Failure.self)
    }
}

// MARK: CustomError / Never -> CustomError

extension Publisher where Output:Publisher, Output.Failure==Never {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
    ///
    /// The `SequentialFlatMap` doesn't buffer the incoming publishers; instead it controls the demand only asking a new publisher when it needs it (i.e. sequentially).
    /// If you use a `Subject` to send a barrage of publishers, they will be ignored except the first one. If you want to received all publishers, you would need to add a `buffer` operator before this `sequentialFlatMap`; such as:
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
    /// - attention: If an error is emitted by the upstream, it is forwarded immediately, effectively shutting down this stream. Also, this stream only successfully completes when both the upstream and the children publishers complete.
    /// - returns: A publisher executing the received value publishers one at a time.
    public func sequentialFlatMap() -> Publishers.SequentialFlatMap<Output,Self,Failure> {
        .init(upstream: self, failure: Failure.self)
    }
}

// MARK: CustomError / CustomError -> CustomError

extension Publisher where Output:Publisher, Output.Failure==Failure {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
    ///
    /// The `SequentialFlatMap` doesn't buffer the incoming publishers; instead it controls the demand only asking a new publisher when it needs it (i.e. sequentially).
    /// If you use a `Subject` to send a barrage of publishers, they will be ignored except the first one. If you want to received all publishers, you would need to add a `buffer` operator before this `sequentialFlatMap`; such as:
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
    public func sequentialFlatMap() -> Publishers.SequentialFlatMap<Output,Self,Failure> {
        .init(upstream: self, failure: Failure.self)
    }
}

// MARK: Different Errors -> Swift.Error

extension Publisher where Output:Publisher {
    /// Ask the upstream for one publisher at a time. This operator executes a *child* publisher and once the child has completed successfully, it asks for the next one.
    ///
    /// The `SequentialFlatMap` doesn't buffer the incoming publishers; instead it controls the demand only asking a new publisher when it needs it (i.e. sequentially).
    /// If you use a `Subject` to send a barrage of publishers, they will be ignored except the first one. If you want to received all publishers, you would need to add a `buffer` operator before this `sequentialFlatMap`; such as:
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
}
