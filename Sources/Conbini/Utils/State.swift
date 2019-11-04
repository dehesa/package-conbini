import Combine
import Foundation

/// Property Wrapper used to guard a combine conduit state behind a unfair lock.
@propertyWrapper internal final class Locked<WaitConfiguration,ActiveConfiguration>: CustomCombineIdentifierConvertible {
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
    
    /// Convenience initializer setting the property wrapper to the `awaitingSubscription` state.
    convenience init(awaiting configuration: WaitConfiguration) {
        self.init(wrappedValue: .awaitingSubscription(configuration))
    }
    
    /// Convenience initializer setting the property wrapper to the `active` state.
    convenience init(active configuration: ActiveConfiguration) {
        self.init(wrappedValue: .active(configuration))
    }
    
    deinit {
        self.unfairLock.deallocate()
    }
    
    var wrappedValue: Content {
        get { return self.state }
        set { self.state = newValue }
    }
}

extension Locked {
    /// Locks the state to other threads.
    func lock() {
        os_unfair_lock_lock(self.unfairLock)
    }
    
    /// Unlocks the state for other threads.
    func unlock() {
        os_unfair_lock_unlock(self.unfairLock)
    }
    
    /// Nullify the state and returns the previous state value.
    @discardableResult
    func terminate() -> Content {
        os_unfair_lock_lock(self.unfairLock)
        let result = self.state
        self.state = nil
        os_unfair_lock_unlock(self.unfairLock)
        return result
    }
}

/// The possible conduit states.
enum State<WaitConfiguration,ActiveConfiguration>: ExpressibleByNilLiteral {
    /// A subscriber has been sent upstream, but a subscription acknowledgement hasn't been received yet.
    case awaitingSubscription(WaitConfiguration)
    /// The conduit is active and potentially receiving and sending events.
    case active(ActiveConfiguration)
    /// The conduit has been cancelled or it has been terminated.
    case terminated
    
    init(nilLiteral: ()) {
        self = .terminated
    }
}
