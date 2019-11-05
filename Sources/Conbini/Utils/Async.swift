/// Namespace for asynchronous utilities.
public enum Async {
    /// Indication whether the transformation closure will continue emitting values (i.e. `.continue`) or it is done (i.e. `finished`).
    public enum Request: Equatable {
        /// The transformation closure will continue emitting values. Failing to do so will make the publisher to never complete nor process further upstream values.
        case `continue`
        /// The transformation closure is done and further upstream values may be processed.
        case finished
    }

    /// The permission returned by a promise.
    public enum Permission: ExpressibleByBooleanLiteral, Equatable {
        /// The transformation closure is allowed to send a new value.
        case allowed
        /// The transformation closure is forbidden to send a new value. If it tries to do so, it will get ignored.
        case forbidden
        
        public init(booleanLiteral value: BooleanLiteralType) {
            switch value {
            case true: self = .allowed
            case false: self = .forbidden
            }
        }
    }

    /// The closure type used to return the result of the transformation.
    /// - parameter result: The transformation result.
    /// - parameter request: Whether the closure want to continue sending values or it is done.
    /// - returns: Enum indicating whether the closure can keep calling this promise.
    public typealias Promise<Result> = (_ result: Result, _ request: Request) -> Permission
    /// The closure type being stored for value transformation.
    /// - parameter value: The value received from the upstream.
    /// - parameter promise: The promise to call once the transformation is done.
    public typealias Closure<Value,Result> = (_ value: Value, _ promise: @escaping Promise<Result>) -> Void
}
