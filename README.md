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

## Subscribers

The following operators are actually testing subscribers. They allow easier testing for publisher chains making the test wait till a specific expectation is fulfilled (or making the test fail in a negative case). Furthermore, if a timeout ellapses or a expectation is not fulfilled, the affected test line will be marked _in red_ correctly in Xcode.

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

-   `expectAtLeast` subscribes to a publisher making the running test wait for at least the provided amount of values.
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

## References

-   Apple's [Combine documentation](https://developer.apple.com/documentation/combine).
-   [OpenCombine](https://github.com/broadwaylamb/OpenCombine) is an open source implementation of Apple's Combine framework.
-   [CombineX](https://github.com/cx-org/CombineX) is an open source implementation of Apple's Combine framework.
-   [SwiftUI-Notes](https://heckj.github.io/swiftui-notes/) is a collection of notes on Swift UI and Combine.
-   [Combine book](https://store.raywenderlich.com/products/combine-asynchronous-programming-with-swift) is an excellent Ray Wenderlich book about the Combine framework.

> The framework name references both the `Combine` framework and the helpful Japanese convenience stores 😄
