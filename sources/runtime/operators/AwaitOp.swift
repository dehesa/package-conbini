import Combine
import Foundation

extension Publisher {
  /// Subscribes to the receiving publichser and expects a single value and a subsequent successfull completion.
  ///
  /// If no values is received, or more than one value is received, or a failure is received, the program will crash.
  /// - warning: The publisher must receive the value and completion event in a different queue from the queue where this property is called or the code will never execute.
  @inlinable public var await: Output {
    let group = DispatchGroup()
    group.enter()

    var value: Output? = nil
    let cancellable = self.sink(fixedDemand: 1, receiveCompletion: {
      switch $0 {
      case .failure(let error): fatalError("\(error)")
      case .finished:
        guard case .some = value else { fatalError() }
        group.leave()
      }
    }, receiveValue: { value = $0 })

    group.wait()
    cancellable.cancel()
    return value!
  }
}
