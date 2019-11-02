import Combine

extension Publisher {
    /// This operator creates a subscribers (such as the `.sink` operator) which subscribes upstream and expects a single value and a subsequent successful completion.
    /// - If a single value is sent, followed by a successful completion; the handler is called with such value.
    /// - If a failure occurs at any point; then handler is called with such failure.
    /// - If more than one value is sent; the subscriber gets cancelled and the handler is never called.
    /// - If a completion occurs and no value has been sent, the subscriber completes without calling the handler.
    /// - parameter handler: Returns the result of the publisher.
    @discardableResult
    public func result(_ handler: @escaping (Result<Output,Failure>)->Void) -> AnyCancellable? {
        var (value, cancellable): (Output?, AnyCancellable?) = (nil, nil)
        let subscriber = Subscribers.Sink<Output,Failure>(receiveCompletion: {
            switch $0 {
            case .failure(let error):
                handler(.failure(error))
            case .finished:
                if let value = value {
                    handler(.success(value))
                }
            }
            
            (value, cancellable) = (nil, nil)
        }, receiveValue: {
            guard case .none = value else {
                cancellable?.cancel()
                (value, cancellable) = (nil, nil)
                return
            }
            value = $0
        })
        
        let result = AnyCancellable(subscriber)
        cancellable = result
        self.subscribe(subscriber)
        
        return result
    }
}
