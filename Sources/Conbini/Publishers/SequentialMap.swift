import Combine
import Foundation

extension Publishers {
    /// Transforms all elements from the upstream publisher with a provided closure.
    public struct SequentialMap<Upstream,Output>: Publisher where Upstream:Publisher {
        public typealias Failure = Upstream.Failure
        /// The closure type used to return the result of the transformation.
        /// - parameter result: The transformation result.
        /// - parameter request: Whether the closure want to continue sending values or it is done.
        /// - returns: Boolean indicating whether the closure can keep calling this promise.
        public typealias Promise = (_ result: Output, _ request: Request) -> Permission
        /// The closure type being stored for value transformation.
        /// - parameter value: The value received from the upstream.
        /// - parameter promise: The promise to call once the transformation is done.
        public typealias Closure = (_ value: Upstream.Output, _ promise: @escaping Promise) -> Void
        /// The closure type being stored for value transformation.
        /// - parameter value: The value received from the upstream.
        /// - parameter promise: The promise to call once the transformation is done.
        /// - parameter result: The transformed result.
        public typealias SimpleClosure = (_ value: Upstream.Output, _ promise: @escaping (_ result: Output)->Void) -> Void

        /// The upstream publisher.
        private let upstream: Upstream
        /// The closure generating the downstream value.
        /// - note: The closure is kept in the publisher; thus, if you keep the publisher around any reference in the closure will be kept too.
        private let closure: Closure
        /// Creates a publisher that transforms the incoming value into another value, but may respond at a time in the future.
        /// - parameter upstream: The event emitter to the publisher being created.
        /// - parameter transform: Closure in charge of transforming the values.
        /// - note: The closure is kept in the publisher; thus, if you keep the publisher around any reference in the closure will be kept too.
        public init(upstream: Upstream, transform: @escaping Closure) {
            self.upstream = upstream
            self.closure = transform
        }

        public func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            let conduit = Conduit(downstream: subscriber, closure: self.closure)
            upstream.subscribe(conduit)
        }
    }
}

extension Publishers.SequentialMap {
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
}

extension Publishers.SequentialMap {
    /// Subscription representing an activated `SequentialMap` publisher.
    fileprivate final class Conduit<Downstream>: Subscription, Subscriber where Downstream:Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        /// Performant non-rentrant unfair lock.
        private var lock: os_unfair_lock
        /// The `Conduit`'s current state.
        private var state: State
        
        /// Creates a representation of an `SequentialMap` publisher.
        init(downstream: Downstream, closure: @escaping Closure) {
            self.lock = .init()
            self.state = .awaitingSubscription(downstream: downstream, closure: closure)
        }
        
        deinit {
            self.cancel()
        }
        
        func receive(subscription: Subscription) {
            os_unfair_lock_lock(&self.lock)
            switch self.state {
            case .awaitingSubscription(let downstream, let closure):
                self.state = .active(.init(upstream: subscription, downstream: downstream, closure: closure))
                os_unfair_lock_unlock(&self.lock)
                downstream.receive(subscription: self)
            case .active: fatalError()
            case .terminated: os_unfair_lock_unlock(&self.lock)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            precondition(demand >= 0)
            
            os_unfair_lock_lock(&self.lock)
            guard let config = self.state.configuration else {
                return os_unfair_lock_unlock(&self.lock)
            }
            
            config.demand += demand
            guard config.demand > 0 else {
                return os_unfair_lock_unlock(&self.lock)
            }
            
            guard case .idle = config.status else {
                return os_unfair_lock_unlock(&self.lock)
            }
            
            guard let value = config.buffer.popFirst() else {
                if let upstream = config.upstream {
                    os_unfair_lock_unlock(&self.lock)
                    return upstream.request(.max(1))
                } else {
                    self.state = .terminated
                    os_unfair_lock_unlock(&self.lock)
                    return config.downstream.receive(completion: .finished)
                }
            }
            
            let closure = config.closure
            let promise = self.makePromise()
            config.status = .processing
            os_unfair_lock_unlock(&self.lock)
            closure(value, promise)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            os_unfair_lock_lock(&self.lock)
            guard let config = self.state.configuration else {
                os_unfair_lock_unlock(&self.lock)
                return .none
            }
            
            config.buffer.append(input)
            guard case .idle = config.status, config.demand > 0 else {
                os_unfair_lock_unlock(&self.lock)
                return .none
            }
            
            let closure = config.closure
            let value = config.buffer.removeFirst()
            let promise = self.makePromise()
            config.status = .processing
            os_unfair_lock_unlock(&self.lock)
            
            closure(value, promise)
            return .none
        }
        
        /// - precondition: When this function is called `self` is within the lock and in an active state.
        private func makePromise() -> Promise {
            var isFinished = false
            
            return { [weak self] (result, request) in
                guard let self = self else { return .forbidden }
                
                os_unfair_lock_lock(&self.lock)
                guard let config = self.state.configuration, !isFinished else {
                    os_unfair_lock_unlock(&self.lock)
                    return .forbidden
                }
                
                assert(config.status == .processing)
                assert(config.demand > 0)
                
                let downstream = config.downstream
                config.demand -= 1
                
                guard case .continue = request else {
                    isFinished = true
                    config.status = .idle
                    os_unfair_lock_unlock(&self.lock)
                    
                    self.request(downstream.receive(result))
                    return .forbidden
                }
                
                let totalDemand = config.demand
                os_unfair_lock_unlock(&self.lock)
                
                guard totalDemand == .none else {
                    self.request(downstream.receive(result))
                    return .allowed
                }
                
                let demand = downstream.receive(result)
                precondition(demand >= 0)
                
                os_unfair_lock_lock(&self.lock)
                config.demand += demand
                if config.demand > 0 {
                    os_unfair_lock_unlock(&self.lock)
                    return .allowed
                } else if config.upstream == nil && config.buffer.isEmpty {
                    isFinished = true
                    self.state = .terminated
                    os_unfair_lock_unlock(&self.lock)
                    config.downstream.receive(completion: .finished)
                } else {
                    isFinished = true
                    config.status = .idle
                    os_unfair_lock_unlock(&self.lock)
                }
                
                return .forbidden
            }
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            os_unfair_lock_lock(&self.lock)
            guard let config = self.state.configuration else {
                return os_unfair_lock_unlock(&self.lock)
            }
            
            switch (completion, config.status) {
            case (.failure, _):
                fallthrough
            case (.finished, .idle) where config.buffer.isEmpty:
                self.state = .terminated
                let downstream = config.downstream
                os_unfair_lock_unlock(&self.lock)
                downstream.receive(completion: completion)
            default:
                config.upstream = nil
                os_unfair_lock_unlock(&self.lock)
            }
        }
        
        func cancel() {
            os_unfair_lock_lock(&self.lock)
            let state = self.state
            self.state = .terminated
            os_unfair_lock_unlock(&self.lock)
            
            guard case .active(let config) = state else { return }
            config.upstream?.cancel()
        }
        
        /// Holds information necessary to manage the `Conduit`.
        enum State {
            case awaitingSubscription(downstream: Downstream, closure: Closure)
            case active(Configuration)
            case terminated
            
            /// Returns the active configuration or `nil` if the state is not `.active`.
            /// - warning: This property crashes for states `.awaitingSubscription`.
            var configuration: Configuration? {
                switch self {
                case .active(let configuration): return configuration
                case .terminated: return nil
                case .awaitingSubscription: fatalError()
                }
            }
            
            /// Holds information necessary to manage the `SequentialMap` subscription once it has been activated.
            final class Configuration {
                /// The subscription used to manage the upstream back-pressure.
                var upstream: Subscription?
                /// The subscriber receiving the input and completion.
                let downstream: Downstream
                /// The closure being called for each upstream value emitted.
                let closure: Closure
                /// Buffer for values received from the upstream.
                var buffer: [Upstream.Output]
                /// The values requested by the downstream.
                var demand: Subscribers.Demand
                /// Boolean indicating whether the `Conduit` is currently transforming a value.
                var status: Status
                /// Designated initializer providing the requried upstream and downstream.
                init(upstream: Subscription, downstream: Downstream, closure: @escaping Closure) {
                    self.upstream = upstream
                    self.downstream = downstream
                    self.closure = closure
                    self.buffer = .init()
                    self.demand = .none
                    self.status = .idle
                }
            }
        }
    }
}

extension Publishers.SequentialMap.Conduit.State.Configuration {
    /// Whether there is a closure being executed.
    enum Status: Equatable {
        case idle
        case processing
    }
}
