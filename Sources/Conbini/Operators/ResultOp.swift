import Combine

extension Publisher {
    /// Creates a subscribers which subscribes upstream and expects a single value and a subsequent successful completion.
    /// - If a single value is sent followed by a successful completion; the handler is called with such value.
    /// - If a failure occurs at any point; the handler is called with such failure.
    /// - If more than one value is sent; the subscriber gets cancelled, `unexpected` is called and depending on whether an error is generated, the handler is called or not.
    /// - If a completion occurs and no value has been sent, the subscriber gets cancelled, `unexpected` is called and depending on whether an error is generated, the handler is called or not.
    /// - parameter unexpected: Autoclosure generating an optional error to pass to the `handler` when upstream doesn't behave as expected. If `nil`, the `handler` won't be called when an unexpected behavior occurs.
    /// - parameter handler: Returns the result of the publisher.
    /// - returns: The `Cancellable` that can stop/cancel the subscriber.
    @discardableResult
    public func result(onUnexpected unexpected: @escaping @autoclosure ()->Failure? = nil, _ handler: @escaping (Result<Output,Failure>)->Void) -> AnyCancellable {
        var value: Output? = nil
        weak var cancellable: AnyCancellable? = nil
        
        let subscriber = Subscribers.Sink<Output,Failure>(receiveCompletion: {
            switch $0 {
            case .failure(let error):
                handler(.failure(error))
            case .finished:
                if let value = value {
                    handler(.success(value))
                } else if let error = unexpected() {
                    handler(.failure(error))
                }
            }
            
            (value, cancellable) = (nil, nil)
        }, receiveValue: {
            guard case .none = value else {
                cancellable?.cancel()
                (value, cancellable) = (nil, nil)
                guard let error = unexpected() else { return }
                return handler(.failure(error))
            }
            value = $0
        })
        
        let result = AnyCancellable(subscriber)
        cancellable = result
        
        self.subscribe(subscriber)
        return result
    }
}
