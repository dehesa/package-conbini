import Combine

/// A publisher that never emits any values and just completes. The completion might be  successful or with a failure (depending on whether an error was returned in the closure).
///
/// This publisher only executes the stored closure when it receives a request with a demand greater than zero. Right after closure execution, the closure is removed and cleaned up.
public struct DeferredComplete<Output,Failure>: Publisher where Failure:Swift.Error {
  /// The closure type being store for delayed execution.
  public typealias Closure = () -> Failure?

  /// Deferred closure.
  /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
  public let closure: Closure

  /// Creates a publisher that forwards a successful completion once it receives a positive request (i.e. a request greater than zero)
  public init() {
    self.closure = { nil }
  }

  /// Creates a publisher that completes successfully or fails depending on the result of the given closure.
  /// - parameter output: The output type of this *empty* publisher. It is given here as convenience, since it may help compiler inferral.
  /// - parameter closure: The closure which produces an empty successful completion (if it returns `nil`) or a failure (if it returns an error).
  /// - attention: The closure is kept till a greater-than-zero demand is received (at which point, it is executed and then deleted).
  @inlinable public init(output: Output.Type = Output.self, closure: @escaping Closure) {
    self.closure = closure
  }

  /// Creates a publisher that fails with the error provided.
  /// - parameter error: *Autoclosure* that will get executed on the first positive request (i.e. a request greater than zero).
  @inlinable public init(error: @autoclosure @escaping ()->Failure) {
    self.closure = { error() }
  }

  public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
    let subscription = _Conduit(downstream: subscriber, closure: self.closure)
    subscriber.receive(subscription: subscription)
  }
}

private extension DeferredComplete {
  /// The shadow subscription chain's origin.
  final class _Conduit<Downstream>: Subscription where Downstream:Subscriber, Downstream.Failure==Failure {
    /// Enum listing all possible conduit states.
    @ConduitLock private var state: ConduitState<Void,_Configuration>

    init(downstream: Downstream, closure: @escaping Closure) {
      self.state = .active(_Configuration(downstream: downstream, closure: closure))
    }

    deinit {
      self._state.invalidate()
    }

    func request(_ demand: Subscribers.Demand) {
      guard demand > 0, case .active(let config) = self._state.terminate() else { return }

      if let error = config.closure() {
        return config.downstream.receive(completion: .failure(error))
      } else {
        return config.downstream.receive(completion: .finished)
      }
    }

    func cancel() {
      self._state.terminate()
    }
  }
}

private extension DeferredComplete._Conduit {
  /// Values needed for the subscription's active state.
  struct _Configuration {
    /// The downstream subscriber awaiting any value and/or completion events.
    let downstream: Downstream
    /// The closure generating the succesful/failure completion.
    let closure: DeferredComplete.Closure
  }
}
