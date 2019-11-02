//import Combine
//
//extension Publishers {
//    /// A publisher that transform all elements from the upstream publisher with a provided closure.
//    public struct AsyncMap<Upstream,Output>: Publisher where Upstream:Publisher {
//        public typealias Failure = Upstream.Failure
//        /// The closure type being stored for value transformation.
//        /// - parameter value: The value received from the upstream.
//        /// - parameter promise: The promise to call once the transformation is done.
//        public typealias Closure = (_ value: Upstream.Output, _ promise: (Self.Output)->Void) -> Void
//
//        /// The upstream publisher.
//        private let upstream: Upstream
//        /// The closure generating the downstream value.
//        /// - note: The closure is kept in the publisher; thus, if you keep the publisher around any reference in the closure will be kept too.
//        private let closure: Self.Closure
//        /// Creates a publisher that transforms the incoming value into another value, but may respond at a time in the future.
//        /// - parameter upstream: The event emitter to the publisher being created.
//        /// - parameter transform: Closure in charge of transforming the values.
//        init(upstream: Upstream, transform: @escaping Closure) {
//            self.upstream = upstream
//            self.closure = transform
//        }
//
//        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
//            #warning("Implement me")
//        }
//    }
//}
