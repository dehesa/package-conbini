import Combine

extension Subscribers.Completion {
    /// Transform the error from the receiving failure type to a new type.
    @_transparent internal func mapError<E>(_ handler: (Failure)->E) -> Subscribers.Completion<E> {
        switch self {
        case .finished: return .finished
        case .failure(let error): return .failure(handler(error))
        }
    }
}
