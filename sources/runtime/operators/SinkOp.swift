import Combine

extension Publisher {
  /// Subscribe to the receiving publisher and request exactly `fixedDemand` values.
  ///
  /// This operator may receive zero to `fixedDemand` of values before completing, but no more.
  /// - parameter fixedDemand: The maximum number of values to be received.
  /// - parameter receiveCompletion: The closure executed when the provided amount of values are received or a completion event is received.
  /// - parameter receiveValue: The closure executed when a value is received.
  @inlinable public func sink(fixedDemand: Int, receiveCompletion: ((Subscribers.Completion<Failure>)->Void)?, receiveValue: ((Output)->Void)?) -> AnyCancellable {
    let subscriber = Subscribers.FixedSink(demand: fixedDemand, receiveCompletion: receiveCompletion, receiveValue: receiveValue)
    let cancellable = AnyCancellable(subscriber)
    self.subscribe(subscriber)
    return cancellable
  }

  /// Subscribe to the receiving publisher requesting `maxDemand` values and always keeping the same backpressure.
  /// - parameter maxDemand: The maximum number of in-flight values.
  /// - parameter receiveCompletion: The closure executed when the provided amount of values are received or a completion event is received.
  /// - parameter receiveValue: The closure executed when a value is received.
  @inlinable public func sink(maxDemand: Subscribers.Demand, receiveCompletion: ((Subscribers.Completion<Failure>)->Void)?, receiveValue: ((Output)->Void)?) -> AnyCancellable {
    let subscriber = Subscribers.GraduatedSink(maxDemand: maxDemand, receiveCompletion: receiveCompletion, receiveValue: receiveValue)
    let cancellable = AnyCancellable(subscriber)
    self.subscribe(subscriber)
    return cancellable
  }
}
