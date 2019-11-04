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
    
    /// Switches the state from `.awaitingSubscription` to `.active` by providing the active configuration parameters.
    ///
    /// If the state is already in `.active`, this function crashes. If the state is `.terminated`, no work is performed.
    func activate(locking priviledgeHandler: (_ config: WaitConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
        self.lock()
        switch self.state {
        case .awaitingSubscription(let config):
            let configuration = priviledgeHandler(config)
            self.state = .active(configuration)
            self.unlock()
            return configuration
        case .terminated:
            self.unlock()
            return nil
        case .active: fatalError()
        }
    }
    
    ///
    func onActive(locking priviledgeHandler: (_ config: ActiveConfiguration)->ActiveConfiguration) -> ActiveConfiguration? {
        self.lock()
        switch self.state {
        case .active(let config):
            self.state = .active(priviledgeHandler(config))
            self.unlock()
            return config
        case .terminated:
            self.unlock()
            return nil
        case .awaitingSubscription: fatalError()
        }
    }
    
    /// Nullify the state and returns the previous state value.
    @discardableResult
    func terminate() -> Content {
        self.lock()
        let result = self.state
        self.state = nil
        self.unlock()
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
