import Combine

extension Publisher where Self.Failure==Never {
    /// Assigns a publisher's output to a property of an object.
    ///
    /// The difference between `assign(to:onWeak:)` and Combine's `assign(to:on:)` is two-fold:
    /// - `assign(to:onWeak:)` doesn't set a _strong bond_ to `object`.
    ///   This breaks memory cycles when `object` also stores the returned cancellable (e.g. passing `self` is a common case).
    /// - `assign(to:onWeak:)` cancels the upstream publisher if it detects `object` is deinitialized.
    ///
    /// The difference between  is that a _strong bond_ is not set to the`object`. This breaks memory cycles when `object` also stores the returned cancellable (e.g. passing `self` is a common case).
    /// - parameter keyPath: A key path that indicates the property to assign.
    /// - parameter object: The object that contains the property. The subscriber assigns the object's property every time it receives a new value.
    /// - returns: An `AnyCancellable` instance. Call `cancel()` on the instance when you no longer want the publisher to automatically assign the property. Deinitializing this instance will also cancel automatic assignment.
    @_transparent public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root,Output>, onWeak object: Root) -> AnyCancellable where Root:AnyObject {
        weak var cancellable: AnyCancellable? = nil
        let cleanup: (Subscribers.Completion<Never>) -> Void = { _ in
            cancellable?.cancel()
            cancellable = nil
        }
        
        let subscriber = Subscribers.Sink<Output,Never>(receiveCompletion: cleanup, receiveValue: { [weak object] (value) in
            guard let object = object else { return cleanup(.finished) }
            object[keyPath: keyPath] = value
        })
        
        let result = AnyCancellable(subscriber)
        cancellable = result
        self.subscribe(subscriber)
        return result
    }
    
    /// Assigns a publisher's output to a property of an object.
    ///
    /// The difference between `assign(to:onUnowned:)` and Combine's `assign(to:on:)` is that a _strong bond_ is not set to the`object`. This breaks memory cycles when `object` also stores the returned cancellable (e.g. passing `self` is a common case).
    /// - parameter keyPath: A key path that indicates the property to assign.
    /// - parameter object: The object that contains the property. The subscriber assigns the object's property every time it receives a new value.
    /// - returns: An `AnyCancellable` instance. Call `cancel()` on the instance when you no longer want the publisher to automatically assign the property. Deinitializing this instance will also cancel automatic assignment.
    @_transparent public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root,Output>, onUnowned object: Root) -> AnyCancellable where Root:AnyObject {
        self.sink(receiveValue: { [unowned object] (value) in
            object[keyPath: keyPath] = value
        })
    }
}

extension Publisher where Self.Failure==Never {
    /// Invoke on the given instance the specified method.
    /// - remark: A strong bond is set to `instance`. If you store the cancellable in the same instance as `instance`, a memory cycle will be created.
    /// - parameter method: A method/function metatype.
    /// - parameter instance: The instance defining the specified method.
    /// - returns: An `AnyCancellable` instance. Call `cancel()` on the instance when you no longer want the publisher to automatically call the method. Deinitializing this instance will also cancel automatic invocation.
    @_transparent public func invoke<Root>(_ method: @escaping (Root)->(Output)->Void, on instance: Root) -> AnyCancellable {
        return self.sink(receiveValue: { (value) in
            method(instance)(value)
        })
    }
    
    /// Invoke on the given instance the specified method.
    ///
    /// The difference between `invoke(_:onWeak:)` and Combine's `invoke(_:on:)` is two-fold:
    /// - `invoke(_:onWeak:)` doesn't set a _strong bond_ to `object`.
    ///   This breaks memory cycles when `object` also stores the returned cancellable (e.g. passing `self` is a common case).
    /// - `invoke(_:onWeak:)` cancels the upstream publisher if it detects `object` is deinitialized.
    ///
    /// - parameter method: A method/function metatype.
    /// - parameter instance: The instance defining the specified method.
    /// - returns: An `AnyCancellable` instance. Call `cancel()` on the instance when you no longer want the publisher to automatically call the method. Deinitializing this instance will also cancel automatic invocation.
    @_transparent public func invoke<Root>(_ method: @escaping (Root)->(Output)->Void, onWeak object: Root) -> AnyCancellable where Root:AnyObject {
        weak var cancellable: AnyCancellable? = nil
        let cleanup: (Subscribers.Completion<Never>) -> Void = { _ in
            cancellable?.cancel()
            cancellable = nil
        }
        
        let subscriber = Subscribers.Sink<Output,Never>(receiveCompletion: cleanup, receiveValue: { [weak object] (value) in
            guard let object = object else { return cleanup(.finished) }
            method(object)(value)
        })
        
        let result = AnyCancellable(subscriber)
        cancellable = result
        self.subscribe(subscriber)
        return result
    }
    
    /// Invoke on the given instance the specified method.
    ///
    /// The difference between `invoke(_:onUnowned:)` and Combine's `invoke(_:on:)` is that a _strong bond_ is not set to the`object`. This breaks memory cycles when `object` also stores the returned cancellable (e.g. passing `self` is a common case).
    /// - parameter method: A method/function metatype.
    /// - parameter instance: The instance defining the specified method.
    /// - returns: An `AnyCancellable` instance. Call `cancel()` on the instance when you no longer want the publisher to automatically call the method. Deinitializing this instance will also cancel automatic invocation.
    @_transparent public func invoke<Root>(_ method: @escaping (Root)->(Output)->Void, onUnowned object: Root) -> AnyCancellable where Root:AnyObject {
        return self.sink(receiveValue: { [unowned object] (value) in
            method(object)(value)
        })
    }
}
