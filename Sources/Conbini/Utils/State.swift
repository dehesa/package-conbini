import Foundation

/// Propperty wrapping a unfair lock and some state (only accessed through the lock).
@propertyWrapper
struct SubscriptionState<State> {
    /// Performant non-rentrant unfair lock.
    private var lock: os_unfair_lock
    /// Generic variable being guarded by the lock.
    private var state: State?
    
    init(wrappedValue: State) {
        self.lock = .init()
        self.state = wrappedValue
    }
    
    var wrappedValue: State {
        mutating get {
            os_unfair_lock_lock(&self.lock)
            defer { os_unfair_lock_unlock(&self.lock) }
            return self.state!
        }
        
        set(newState) {
            os_unfair_lock_lock(&self.lock)
            defer { os_unfair_lock_unlock(&self.lock) }
            self.state = newState
        }
    }
    
    /// Returned the guarded variable and nullify it from the storage in the same operation.
    /// - returns: The previously guarded state.
    @discardableResult mutating func remove() -> State? {
        os_unfair_lock_lock(&self.lock)
        defer { os_unfair_lock_unlock(&self.lock) }
        let result = self.state
        self.state = nil
        return result
    }
}
