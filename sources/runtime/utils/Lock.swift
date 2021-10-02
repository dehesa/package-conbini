import Darwin

/// Property Wrapper used to guard a combine conduit state behind a unfair lock.
///
/// - attention: Always make sure to deinitialize the lock.
@propertyWrapper public struct ConduitLock<WaitConfiguration,ActiveConfiguration> {
  /// Performant non-reentrant unfair lock.
  private var _lock: UnsafeMutablePointer<os_unfair_lock>
  /// Generic variable being guarded by the lock.
  public var value: Value

  public init(wrappedValue: Value) {
    self._lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    self._lock.initialize(to: os_unfair_lock())
    self.value = wrappedValue
  }

  /// Provide thread-safe storage access (within the lock).
  public var wrappedValue: Value {
    get {
      self.lock()
      let content = self.value
      self.unlock()
      return content
    }
    set {
      self.lock()
      self.value = newValue
      self.unlock()
    }
  }
}

extension ConduitLock {
  /// Locks the state to other threads.
  public func lock() {
    os_unfair_lock_lock(self._lock)
  }

  /// Unlocks the state for other threads.
  public func unlock() {
    os_unfair_lock_unlock(self._lock)
  }

  public func invalidate() {
    self._lock.deinitialize(count: 1)
    self._lock.deallocate()
  }
}

extension ConduitLock {
  /// The type of the value being guarded by the lock.
  public typealias Value = ConduitState<WaitConfiguration,ActiveConfiguration>

  /// Switches the state from `.awaitingSubscription` to `.active` by providing the active configuration parameters.
  /// - If the state is already in `.active`, this function crashes.
  /// - If the state is `.terminated`, no work is performed.
  /// - parameter atomic: Code executed within the unfair locks. Don't call anywhere here; just perform computations.
  /// - returns: The active configuration set after the call of this function.
  public mutating func activate(atomic: (WaitConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
    let result: ActiveConfiguration?

    self.lock()
    switch self.value {
    case .awaitingSubscription(let awaitingConfiguration):
      result = atomic(awaitingConfiguration)
      self.value = .active(result.unsafelyUnwrapped)
    case .terminated: result = nil
    case .active: fatalError()
    }
    self.unlock()

    return result
  }

  /// Nullify the state and returns the previous state value.
  @discardableResult public mutating func terminate() -> Value {
    self.lock()
    let result = self.value
    self.value = .terminated
    self.unlock()
    return result
  }
}

