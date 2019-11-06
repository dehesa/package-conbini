import Combine

extension Subscribers.Completion {
    /// Transform the error from the receiving failure type to a new type.
    func mapError<E>(_ handler: (Failure)->E) -> Subscribers.Completion<E> {
        switch self {
        case .finished: return .finished
        case .failure(let error): return .failure(handler(error))
        }
    }
}

/// A type that can store one given type or another.
internal enum Either<A,B> {
    case left(A)
    case right(B)
}
