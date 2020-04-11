import Combine

extension Publishers {
    /// Namespace for asynchronous operations.
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
            
            @_transparent public init(booleanLiteral value: BooleanLiteralType) {
                switch value {
                case true: self = .allowed
                case false: self = .forbidden
                }
            }
        }
    }
}
