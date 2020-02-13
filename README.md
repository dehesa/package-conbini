<p align="center">
    <img src="Assets/Conbini.svg" alt="Conbini icon"/>
</p>

Conbini provides convenience `Publisher`s, operators, and `Subscriber`s to squeeze the most out of Apple's [Combine framework](https://developer.apple.com/documentation/combine).

![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

# Operators

Operators extending a given pipeline:

-   `then` ignores all values and executes the provided publisher once a successful completion is received.
    <br>If a failed completion is emitted, it is forwarded downstream.

    ```swift
    let publisher = setConfigurationOnServer.then {
        subscribeToWebsocket.publisher
    }
    ```

    This operator optionally lets you control backpressure with its `maxDemand` parameter. The parameter behaves like `flatMap`'s `maxPublishers`, which specifies the maximum demand requested to the upstream at any given time.

-   `asyncMap` transforms elements received from upstream (similar to `map`), but the result is returned in a promise instead of using the `return` statement (similar to `Future`).

    ```swift
    let publisher = [1, 2].publisher.asyncMap { (value, promise) in
        queue.async {
            let newValue = String(value * 10)
            promise(newValue)
        }
    }
    ```

    This operator also provides a `try` variant accepting a result (instead of a value).

-   `sequentialMap` transform elements received from upstream (as `asyncMap`) with the twist that it allows you to call multiple times the `promise` callback; effectively transforming one value into many results.

    ```swift
    let publisher = [1, 2].publisher.sequentialMap { (value, promise) in
        queue.async {
            promise(value * 10 + 1, .continue)
            promise(value * 10 + 2, .continue)
            promise(value * 10 + 3, .finished)
        }
    }
    // Downstream will receive: [11, 12, 13, 21, 22, 23]
    ```

    The `SequentialMap` publisher executes one upstream value at a time. It doesn't request or fetch a previously sent upstream value till the `transform` closure is fully done and `promise(..., .finished)` has been called.
    <br>This operator also provides a `try` variant accepting a result (instead of a value).

Operators acting as subscribers:

-   `result` subscribes to the receiving publisher and executes the provided closure when a single value followed by a successful completion is received.
    <br>In case of failure, the handler is executed with such failure.

    ```swift
    let cancellable = serverRequest.result { (result) in
        switch result {
        case .success(let value): ...
        case .failure(let error): ...
        }
    }
    ```

    The operator lets you optionally generate an error (which will be consumed by your `handler`) for unexpected cases, such as when more than one value are received.

# Publishers

-   `Deferred...` publishers accept a closure that is executed once a _greater-than-zero_ demand is requested.
    <br>They have several flavors:

    -   `DeferredValue` emits a single value and then completes.
        <br>The value is not provided/cached, but instead a closure will generate it. The closure is executed once a positive subscription is received.

        ```swift
        let publisher = DeferredValue<Int,CustomError> {
            return intenseProcessing()
        }
        ```

        A `Try` variant is also offered, enabling you to `throw` from within the closure. It loses the concrete error type (i.e. it gets converted to `Swift.Error`).

    -   `DeferredResult` offers the same functionality as `DeferredValue`, but the closure generates a `Result` instead.

        ```swift
        let publisher = DeferredResult {
          guard someExpression else { return .failure(CustomError()) }
          return .success(someValue)
        }
        ```

    -   `DeferredCompletion` offers the same functionality as `DeferredValue`, but the closure only generates a completion event.

        ```swift
        let publisher = DeferredCompletion {
            return errorOrNil
        }
        ```

        A `Try` variant is also offered, enabling you to `throw` from within the closure; but it loses the concrete error type (i.e. gets converted to `Swift.Error`).

    -   `DeferredPassthrough` is similar to wrapping a `Passthrough` subject on a `Deferred` closure, with the diferrence that the `Passthrough` given on the closure is already _wired_ on the publisher chain and can start sending values right away. Also, the memory management is taken care of and every new subscriber receives a new subject (closure re-execution).

        ```swift
        let publisher = DeferredPassthrough { (subject) in
          subject.send(something)
          subject.send(somethingElse)
          subject.send(completion: .finished)
        }
        ```

    There are several reason for these publishers to exist instead of using other `Combine`-provided closure such as `Just`, `Future`, or `Deferred`:

    -   `Future` publishers execute their provided closure right away (upon initialization) and then cache the returned value. That value is then forwarded for any future subscription.
        `Deferred...` closures await for subscriptions and a _greater-than-zero_ demand before executing. This also means, the closure will re-execute for any new subscriber.
    -   `Deferred` is the most similar in functionality, but it only accepts a publisher.

-   `Then` provides the functionality of the `then` operator.

## Extra Functionality

The following are a grab-bag of extra functionality added to Combine:

-   `Publishers.PrefetchStrategy` has been extended with a `.fatalError(message:file:line:)` option to stop execution if the buffer is filled.
    <br>This is useful during development and debugging and for cases when you are sure the buffer will never be filled.

    ```swift
    publisher.buffer(size: 10, prefetch: .keepFull, whenFull: .fatalError())
    ```

# Testing

Conbini provides convenience subscribers to ease code testing. These subscribers make the test wait till a specific expectation is fulfilled (or making the test fail in a negative case). Furthermore, if a timeout ellapses or a expectation is not fulfilled, the affected test line will be marked _in red_ correctly in Xcode.

-   `expectsCompletion` subscribes to a publisher making the running test wait for a successful completion while ignoring all emitted values.

    ```swift
    publisherChain.expectsCompletion(timeout: 0.8, on: test)
    ```

-   `expectsFailure` subscribes to a publisher making the running test wait for a failed completion while ignoring all emitted values.

    ```swift
    publisherChain.expectsFailure(timeout: 0.8, on: test)
    ```

-   `expectsOne` subscribes to a publisher making the running test wait for a single value and a successful completion.
    <br>If more than one values are emitted or the publisher fails, the subscription gets cancelled and the test fails.

    ```swift
    let emittedValue = publisherChain.expectsOne(timeout: 0.8, on: test)
    ```

-   `expectsAll` subscribes to a publisher making the running test wait for zero or more values and a successful completion.

    ```swift
    let emittedValues = publisherChain.expectsAll(timeout: 0.8, on: test)
    ```

-   `expectsAtLeast` subscribes to a publisher making the running test wait for at least the provided amount of values.
    <br>Once the provided amount of values is received, the publisher gets cancelled and the values are returned.

    ```swift
    let emittedValues = publisherChain.expectsAtLeast(values: 5, timeout: 0.8, on: test)
    ```

    This operator/subscriber accepts an optional closure to check every value received.

    ```swift
    let emittedValues = publisherChain.expectsAtLeast(values: 5, timeout: 0.8, on: test) { (value) in
      XCTAssert...
    }
    ```

## Quirks

The testing conveniences depend on [XCTest](https://developer.apple.com/documentation/xctest), which is not available on regular execution. That is why Conbini is offered in two flavors:

-   `import Conbini` includes all code excepts the testing conveniences.
-   `import ConbiniForTesting` includes the testing functionality only.

The rule of thumb is to use `import Conbini` in your regular code (e.g. within your framework or app) and write `import ConbiniForTesting` within your test target files.

# References

-   Apple's [Combine documentation](https://developer.apple.com/documentation/combine).
-   [The Combine book](https://store.raywenderlich.com/products/combine-asynchronous-programming-with-swift) is an excellent Ray Wenderlich book about the Combine framework.
-   [Cocoa with love](https://www.cocoawithlove.com) has a great series of articles about the inner workings of Combine: [1. Protocols](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-1.html), [2. Sharing](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-2.html), [3. Asynchrony](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-3.html).
-   [OpenCombine](https://github.com/broadwaylamb/OpenCombine) is an open source implementation of Apple's Combine framework.
-   [CombineX](https://github.com/cx-org/CombineX) is an open source implementation of Apple's Combine framework.

> The framework name references both the `Combine` framework and the helpful Japanese convenience stores 😄
