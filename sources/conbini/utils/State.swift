/// States where conduit can find itself into.
@frozen internal enum State<WaitConfiguration,ActiveConfiguration>: ExpressibleByNilLiteral {
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

extension State {
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
}

extension State {
    /// Boolean indicating if the state is still active.
    @_transparent var isActive: Bool {
        switch self {
        case .active: return true
        case .awaitingSubscription, .terminated: return false
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
