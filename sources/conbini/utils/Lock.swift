import Darwin

/// Property Wrapper used to guard a combine conduit state behind a unfair lock.
///
/// - attention: Always make sure to deinitialize the lock.
@propertyWrapper internal struct Lock<WaitConfiguration,ActiveConfiguration> {
    /// The type of the value being guarded by the lock.
    typealias Content = State<WaitConfiguration,ActiveConfiguration>
    
    /// Performant non-reentrant unfair lock.
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    /// Generic variable being guarded by the lock.
    private var _content: Content
    
    init(wrappedValue: Content) {
        self._lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self._lock.initialize(to: os_unfair_lock())
        self._content = wrappedValue
    }
    
    /// Provide thread-safe storage access (within the lock).
    var wrappedValue: Content {
        get {
            self.lock()
            let content = self._content
            self.unlock()
            return content
        }
        set {
            self.lock()
            self._content = newValue
            self.unlock()
        }
    }
    
    /// Provides unsafe storage access.
    @_transparent var projectedValue: Content {
        get { self._content }
        set { self._content = newValue }
    }
}

extension Lock {
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
}

extension Lock {
    /// Switches the state from `.awaitingSubscription` to `.active` by providing the active configuration parameters.
    /// - If the state is already in `.active`, this function crashes.
    /// - If the state is `.terminated`, no work is performed.
    /// - parameter atomic: Code executed within the unfair locks. Don't call anywhere here; just perform computations.
    /// - returns: The active configuration set after the call of this function.
    mutating func activate(atomic: (WaitConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
        let result: ActiveConfiguration?
        
        self.lock()
        switch self._content {
        case .awaitingSubscription(let awaitingConfiguration):
            result = atomic(awaitingConfiguration)
            self._content = .active(result.unsafelyUnwrapped)
        case .terminated: result = nil
        case .active: fatalError()
        }
        self.unlock()
        
        return result
    }
    
    /// Nullify the state and returns the previous state value.
    @discardableResult mutating func terminate() -> Content {
        self.lock()
        let result = self._content
        self._content = .terminated
        self.unlock()
        return result
    }
}

