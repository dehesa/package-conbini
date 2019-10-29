/// A type that can store one given type or another.
internal enum Either<A,B> {
    case left(A)
    case right(B)
}
