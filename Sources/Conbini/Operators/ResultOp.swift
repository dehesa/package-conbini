import Combine

extension Publisher {
    /// Subscribes to the upstream and expects a single value and a subsequent successful completion.
    ///
    /// The underlying subscriber is `Subscriber.FixedSink`, which makes it impossible to receive more than one value. That said, here are the possible scenarios:
    /// - If a single value is published, the handler is called with such value.
    /// - If a failure occurs; the handler is called with such failure.
    /// - If a completion occurs and no value has been sent, the subscriber gets cancelled, `onEmpty` is called, and depending on whether an error is generated, the handler is called or not.
    /// - parameter onEmpty: Autoclosure generating an optional error to pass to the `handler` when upstream doesn't behave as expected. If `nil`, the `handler` won't be called when no values are published.
    /// - parameter handler: Returns the result of the publisher.
    /// - parameter result: The value yielded after the subscription.
    /// - returns: `Cancellable` able to stop/cancel the subscription.
    @discardableResult public func result(onEmpty: @escaping @autoclosure ()->Failure? = nil, _ handler: @escaping (_ result: Result<Output,Failure>)->Void) -> AnyCancellable {
        var value: Output? = nil
        
        let subscriber = Subscribers.FixedSink<Output,Failure>(demand: 1, receiveCompletion: {
            switch $0 {
            case .failure(let error):
                handler(.failure(error))
            case .finished:
                if let value = value {
                    handler(.success(value))
                } else if let error = onEmpty() {
                    handler(.failure(error))
                }
            }
            
            value = nil
        }, receiveValue: { value = $0 })
        
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
