import Combine

extension Publisher {
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// Please note:
    /// - Values are processed one at a time; i.e. while the previous value is not fully processed, the next won't start.
    /// - `promise` must be called with the transformed value or the stream will never complete.
    /// ```
    /// [0, 1, 2].publisher.asyncMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        let newValue = String(value)
    ///        promise(newValue)
    ///    }
    /// }
    /// ```
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - parameter value: The value received from upstream.
    /// - parameter promise: The closure to call once the transformation is done.
    /// - parameter result: The value that will be sent downstream.
    /// - returns: A publisher with output `T` and failure `Upstream.Failure`.
    public func asyncMap<T>(_ transform: @escaping (_ value: Output, _ promise: @escaping (_ result: T)->Void) -> Void) -> Publishers.SequentialMap<Self,T> {
        .init(upstream: self) { (value, promise) in
            transform(value) { (result) in
                _ = promise(result, .finished)
            }
        }
    }
    
    /// Transforms all elements from the upstream publisher with a provided `Result<T,F>` generating closure.
    ///
    /// Please note:
    /// - Values are processed one at a time; i.e. while the previous value is not fully processed, the next won't start.
    /// - `promise` must be called with the transformed value (or a failure) or the stream will never complete.
    /// - The `Failure` type for the generated publisher is `Swift.Error` (as it is standard for Combine operators prefixed with `try`).
    /// - The upstream and the `Result<T,F>` failure types may be different.
    /// ```
    /// [0, 1, 2].publisher.asyncTryMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        let newValue = String(value)
    ///        promise(.success(newValue))
    ///    }
    /// }
    /// ```
    /// - parameter failure: The error type for the promise's result. If the Swift compiler is not able to infer the result type, you can explicitly state the failure type here.
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - parameter value: The value received from upstream.
    /// - parameter promise: The closure to call once the transformation is done.
    /// - parameter result: A `Result` wrapping the transformed element or a failure. It is worth noticing, the result failure type doesn't have to be of the same type as the receiving publisher.
    /// - returns: A publisher with output `T` and failure `Swift.Error`.
    public func asyncTryMap<T,F>(failure: F.Type = F.self, _ transform: @escaping (_ value: Output, _ promise: @escaping (_ result: Result<T,F>)->Void) -> Void) -> Publishers.SequentialTryMap<Self,T,F> {
        .init(upstream: self) { (value, promise) in
            transform(value) { (result) in
                _ = promise(result, .finished)
            }
        }
    }
    
    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// The `SequentialMap` publisher transform upstream values (one at a time) allowing the transformation result to be called later on. Also, for each value received the `transform` closure may output several downstream values. Please note:
    /// - Values are processed one at a time; i.e. while the previous value is not fully processed, the next won't start.
    ///   This might be potentially dangerous if the previous value never completes.
    /// - `Promise` accepts the transformed result and a value indicating whether the closure is willing to keep sending values.
    /// ```
    /// [0, 10, 20].publisher.sequentialMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        promise(String(value), .continue)
    ///        promise(String(value + 1), .continue)
    ///        promise(String(value + 2), .finished)
    ///    }
    /// }
    /// ```
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - parameter value: The value received from upstream.
    /// - parameter promise: The closure to call everytime a value is sent downstream.
    /// - parameter result: The value that will be sent downstream.
    /// - parameter request: Whether the closure want to continue sending values or it is done.
    /// - returns: A publisher with output `T` and failure `Upstream.Failure`.
    public func sequentialMap<T>(_ transform: @escaping (_ value: Output, _ promise: @escaping (_ result: T, _ request: Async.Request)->Async.Permission) -> Void) -> Publishers.SequentialMap<Self,T> {
        .init(upstream: self, transform: transform)
    }
    
    /// Transforms all elements from the upstream publisher with a provided `Result<T,F>` generating closure.
    ///
    /// The `SequentialTryMap` publisher transform upstream values (one at a time) allowing the transformation result to be called later on. Also, for each value received the `transform` closure may output several downstream values. Please note:
    /// - Values are processed one at a time; i.e. while the previous value is not fully processed, the next won't start.
    ///   This might be potentially dangerous if the previous value never completes.
    /// - `Promise` accepts the transformed result and a value indicating whether the closure is willing to keep sending values.
    /// - The `Failure` type for the generated publisher is `Swift.Error` (as it is standard for Combine operators prefixed with `try`).
    /// - The upstream and the `Result<T,F>` failure types may be different.
    /// ```
    /// [0, 1, 2].publisher.sequentialTryMap { (value, promise) in
    ///    DispatchQueue.main.async {
    ///        // Some operation with value
    ///        promise( .success(String(value)), .continue )
    ///        promise( .success(String(value + 1)), .continue )
    ///        promise( .failure(CustomError()), .finished )
    ///    }
    /// }
    /// ```
    /// - parameter failure: The error type for the promise's result. If the Swift compiler is not able to infer the result type, you can explicitly state the failure type here.
    /// - parameter transform: A closure that takes the upstream emitted value and expects a promise to be called with the transformed result.
    /// - parameter value: The value received from upstream.
    /// - parameter promise: The promise to call once the transformation is done.
    /// - parameter result: The transformation result.
    /// - parameter request: Whether the closure want to continue sending values or it is done.
    /// - returns: A publisher with output `T` and failure `Swift.Error`.
    public func sequentialTryMap<T,F>(failure: F.Type = F.self, _ transform: @escaping (_ value: Output, _ promise: @escaping (_ result: Result<T,F>, _ request: Async.Request)->Async.Permission) -> Void) -> Publishers.SequentialTryMap<Self,T,F> {
        .init(upstream: self, transform: transform)
    }
}
