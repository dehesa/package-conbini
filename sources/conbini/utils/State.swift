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
    @_transparent var awaitingConfiguration: WaitConfiguration? {
        switch self {
        case .awaitingSubscription(let config): return config
        case .terminated: return nil
        case .active: fatalError()
        }
    }
    
    /// Boolean indicating if the state is still active.
    @_transparent var isActive: Bool {
        switch self {
        case .active: return true
        case .awaitingSubscription, .terminated: return false
        }
    }
    
    /// Returns the `ActiveConfiguration` if the receiving state is at `.active`. `nil` for `.terminated` states, and it produces a fatal error otherwise.
    ///
    /// It is used on places where `Combine` promises that a subscription might only be in `.active` or `.terminated` state, but never on `.awaitingSubscription`.
    @_transparent var activeConfiguration: ActiveConfiguration? {
        switch self {
        case .active(let config): return config
        case .terminated: return nil
        case .awaitingSubscription: fatalError()
        }
    }
    
    /// Boolean indicating if the state has been terminated.
    @_transparent var isTerminated: Bool {
        switch self {
        case .terminated: return true
        case .awaitingSubscription, .active: return false
        }
    }
}

// MARK: -

/// Property Wrapper used to guard a combine conduit state behind a unfair lock.
///
/// - attention: Always make sure to deinitialize the lock.
@propertyWrapper internal struct Lock<WaitConfiguration,ActiveConfiguration> {
    /// The type of the value being guarded by the lock.
    typealias Content = State<WaitConfiguration,ActiveConfiguration>
    
    /// Performant non-reentrant unfair lock.
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    /// Generic variable being guarded by the lock.
    private var _state: Content
    
    init(wrappedValue: Content) {
        self._lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self._lock.initialize(to: os_unfair_lock())
        self._state = wrappedValue
    }
    
    var wrappedValue: Content {
        get { return self._state }
        set { self._state = newValue }
    }

    /// Locks the state to other threads.
    @_transparent func lock() {
        os_unfair_lock_lock(self._lock)
    }
    
    /// Unlocks the state for other threads.
    @_transparent func unlock() {
        os_unfair_lock_unlock(self._lock)
    }
    
    @_transparent func deinitialize() {
        self._lock.deallocate()
    }
    
    /// Switches the state from `.awaitingSubscription` to `.active` by providing the active configuration parameters.
    /// - If the state is already in `.active`, this function crashes.
    /// - If the state is `.terminated`, no work is performed.
    /// - parameter atomic: Code executed within the unfair locks. Don't call anywhere here; just perform computations.
    /// - returns: The active configuration set after the call of this function.
    mutating func activate(atomic: (WaitConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
        self.lock()
        switch self._state {
        case .awaitingSubscription(let config):
            let configuration = atomic(config)
            self._state = .active(configuration)
            self.unlock()
            return configuration
        case .terminated:
            self.unlock()
            return nil
        case .active: fatalError()
        }
    }
    
    /// Nullify the state and returns the previous state value.
    @discardableResult mutating func terminate() -> Content {
        self.lock()
        let result = self._state
        self._state = .terminated
        self.unlock()
        return result
    }
}
