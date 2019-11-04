<p align="center">
    <img src="Assets/Conbini.svg" alt="Conbini icon"/>
</p>

Conbini provides convenience `Publisher`s, operators, and `Subscriber`s to squeeze the most out of Apple's [Combine framework](https://developer.apple.com/documentation/combine).

![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

## Operators

-   `then` ignores all values and executes the provided publisher once a successful completion is received.
    If a failed completion is emitted, it is forwarded downstream.

    ```swift
    let publisher = setConfigurationOnServer.then {
        subscribeToWebsocket.publisher
    }
    ```

-   `asyncMap` transforms elements received from upstream (similar to `map`), but the result is returned in a promise instead of using the `return` statement (similar to `Future`).
    Useful when asynchronous operations must be performed sequentially on a value.

    ```swift
    let publisher = [1, 2].publisher.asyncMap { (value, promise) in
        queue.async {
            let newValue = String(value * 10)
            promise(newValue)
        }
    }
    ```

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

-   `sequentialFlatMap` performs a similar operation to `flatMap` (i.e. flattens/executes a publisher emitted from upstream); but instead of accepting _willy-nilly_ all emitted publishers, it only requests one value at a time (through backpressure mechanisms).
    Useful for operations/enpoints that must be performed sequentially.

    ```swift
    [enpointA, endpointB, endpointC].publisher
        .sequentialFlatMap()
    // Downstream will receive: [resultEndpointA, resultEndpointB, resultEndpointC]
    ```

    This publisher works "as expected" even with upstream publishers that disregard backpressure (e.g. `PassthroughSubject`). It buffers publishers internally and execute them depending on the subscriber's demand and whether a publisher is currently _in operation_. Do note, that if a failure completion is received, the whole publisher will finish and any publisher being buffered won't have a chance to execute. This is a similar behavior as Combine's `buffer()` operator.

-   `result` subscribes to the receiving publisher and execute the provided closure when a single value followed by a successful completion is received.
    In case of failure, the handler is executed with such failure.

    ```swift
    let cancellable = serverRequest.result { (result) in
        switch result {
        case .success(let value): ...
        case .failure(let error): ...
        }
    }
    ```

## Publishers

-   `Complete` never emits a value and just completes (whether successfully or with a failure).
    It offers similar functionality to `Empty` and `Failure`, but in a single type. Also, the completion only happens once a _greater-than-zero_ demand is requested.
    ```swift
    let publisherA = Complete<Int,CustomError>(error: nil)
    let publisherB = Complete(error: CustomError())
    ```
    There are two more convenience initializers setting the publisher's `Output` and/or `Failure` to `Never` if the generic types are not explicitly stated.
-   `Deferred...` publishers accept a closure that is executed once a _greater-than-zero_ demand is requested.
    They have several flavors:

    -   `DeferredValue` emits a single value and then completes; however, the value is not provided/cached, but instead a closure which will generate the emitted value is executed per subscription received.

        ```swift
        let publisher = DeferredValue {
            return try someHeavyCalculations()
        }
        ```

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
          try somethingThatMightFail()
        }
        ```

    -   `DeferredPassthrough` is similar to wrapping a `Passthrough` subject on a `Deferred` closure, with the diferrence that the `Passthrough` given on the closure is already _wired_ on the publisher chain and can start sending values right away. Also, the memory management is taken care of and every new subscriber receives a new subject (closure re-execution).

        ```swift
        let publisher = DeferredPassthrough { (subject) in
          subject.send(something)
          subject.send(completion: .finished)
        }
        ```

    There are several reason for these publishers to exist instead of using other `Combine`-provided closure such as `Just`, `Future`, or `Deferred`:

    -   `Future` publishers execute their provided closure right away (upon initialization) and then cache the returned value. That value is then forwarded for any future subscription.
        `Deferred...` closures await for subscriptions and a _greater-than-zero_ demand before executing. This also means, the closure will re-execute for any new subscription.
    -   `Deferred` is the most similar in functionality, but it only accepts a publisher.

-   `Then` provides the functionality of the `then` operator.

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
    If more than one values are emitted or the publisher fails, the subscription gets cancelled and the test fails.

    ```swift
    let emittedValue = publisherChain.expectsOne(timeout: 0.8, on: test)
    ```

-   `expectsAll` subscribes to a publisher making the running test wait for zero or more values and a successful completion.

    ```swift
    let emittedValues = publisherChain.expectsAll(timeout: 0.8, on: test)
    ```

-   `expectsAtLeast` subscribes to a publisher making the running test wait for at least the provided amount of values.
    Once the provided amount of values is received, the publisher gets cancelled and the values are returned.

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

Conbini testing conveniences depend on [XCTest](https://developer.apple.com/documentation/xctest), which is not available on regular execution. That is why Conbini is offered in two flavors:

-   `import Conbini` includes all code excepts the testing conveniences.
-   `import ConbiniForTesting` includes everything.

The rule of thumb is to use `import Conbini` in your regular code (e.g. within your framework or app) and write `import ConbiniForTesting` within your test target files.

# References

-   Apple's [Combine documentation](https://developer.apple.com/documentation/combine).
-   [OpenCombine](https://github.com/broadwaylamb/OpenCombine) is an open source implementation of Apple's Combine framework.
-   [CombineX](https://github.com/cx-org/CombineX) is an open source implementation of Apple's Combine framework.
-   [The Combine book](https://store.raywenderlich.com/products/combine-asynchronous-programming-with-swift) is an excellent Ray Wenderlich book about the Combine framework.
-   [Cocoa with love](https://www.cocoawithlove.com) has a great series of articles about the inner workings of Combine: [1. Protocols](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-1.html), [2. Sharing](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-2.html), [3. Asynchrony](https://www.cocoawithlove.com/blog/twenty-two-short-tests-of-combine-part-3.html).

> The framework name references both the `Combine` framework and the helpful Japanese convenience stores 😄
