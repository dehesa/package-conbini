import Combine
import Foundation

/// States where conduit can find itself into.
internal enum State<WaitConfiguration,ActiveConfiguration>: ExpressibleByNilLiteral {
    /// A subscriber has been sent upstream, but a subscription acknowledgement hasn't been received yet.
    case awaitingSubscription(WaitConfiguration)
    /// The conduit is active and potentially receiving and sending events.
    case active(ActiveConfiguration)
    /// The conduit has been cancelled or it has been terminated.
    case terminated
    
    init(nilLiteral: ()) {
        self = .terminated
    }
    
    /// Returns the `WaitConfiguration` if the receiving state is at `.awaitingSubscription`. `nil` for `.terminated` states, and it produces a fatal error otherwise.
    ///
    /// It is used on places where `Combine` promises that a subscription might only be in `.awaitingSubscription` or `.terminated` state, but never on `.active`.
    var awaitingConfiguration: WaitConfiguration? {
        switch self {
        case .awaitingSubscription(let config): return config
        case .terminated: return nil
        case .active: fatalError()
        }
    }
    
    /// Returns the `ActiveConfiguration` if the receiving state is at `.active`. `nil` for `.terminated` states, and it produces a fatal error otherwise.
    ///
    /// It is used on places where `Combine` promises that a subscription might only be in `.active` or `.terminated` state, but never on `.awaitingSubscription`.
    var activeConfiguration: ActiveConfiguration? {
        switch self {
        case .active(let config): return config
        case .terminated: return nil
        case .awaitingSubscription: fatalError()
        }
    }
}

/// Property Wrapper used to guard a combine conduit state behind a unfair lock.
@propertyWrapper internal final class Lock<WaitConfiguration,ActiveConfiguration> {
    /// The type of the value being guarded by the lock.
    typealias Content = State<WaitConfiguration,ActiveConfiguration>
    
    /// Performant non-reentrant unfair lock.
    private var unfairLock: UnsafeMutablePointer<os_unfair_lock>
    /// Generic variable being guarded by the lock.
    private var state: Content
    
    init(wrappedValue: Content) {
        self.unfairLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.unfairLock.initialize(to: os_unfair_lock())
        self.state = wrappedValue
    }
    
    deinit {
        self.unfairLock.deallocate()
    }
    
    var wrappedValue: Content {
        get { return self.state }
        set { self.state = newValue }
    }
}

extension Lock {
    /// Locks the state to other threads.
    func lock() {
        os_unfair_lock_lock(self.unfairLock)
    }
    
    /// Unlocks the state for other threads.
    func unlock() {
        os_unfair_lock_unlock(self.unfairLock)
    }
    
    /// Switches the state from `.awaitingSubscription` to `.active` by providing the active configuration parameters.
    /// - If the state is already in `.active`, this function crashes.
    /// - If the state is `.terminated`, no work is performed.
    /// - parameter atomic: Code executed within the unfair locks. Don't call anywhere here; just perform computations.
    /// - returns: The active configuration set after the call of this function.
    func activate(atomic: (WaitConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
        self.lock()
        switch self.state {
        case .awaitingSubscription(let config):
            let configuration = atomic(config)
            self.state = .active(configuration)
            self.unlock()
            return configuration
        case .terminated:
            self.unlock()
            return nil
        case .active: fatalError()
        }
    }
    
    /// Nullify the state and returns the previous state value.
    @discardableResult func terminate() -> Content {
        self.lock()
        let result = self.state
        self.state = .terminated
        self.unlock()
        return result
    }
}
