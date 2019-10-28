#if canImport(XCTest)
import XCTest
import Combine
import Foundation

extension Publisher {
    /// Expects the receiving publisher to complete (with or without values) within the provided timeout.
    ///
    /// This operator will subscribe to the publisher chain and "block" the running test till the expectation is completed or thet timeout ellapses.
    /// - precondition: `timeout` must be greater than or equal to zero.
    /// - parameter timeout: The maximum amount of seconds that the test will wait. It must be greater or equal to zero.
    /// - parameter test: The test were the expectation shall be fulfilled.
    /// - parameter description: The expectation description.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    public func expectsCompletion(timeout: TimeInterval, on test: XCTWaiterDelegate, _ description: String = "The publisher completes successfully", file: StaticString = #file, line: UInt = #line) {
        precondition(timeout >= 0)
        let exp = XCTestExpectation(description: description)
        
        let cancellable = self.sink(receiveCompletion: {
            switch $0 {
            case .finished: exp.fulfill()
            case .failure(let e): XCTFail("The publisher completed with failure when successfull completion was expected.\n\(e)\n", file: file, line: line)
            }
        }, receiveValue: { _ in return })
        
        let waiter = XCTWaiter(delegate: test)
        waiter.wait(for: [exp], timeout: timeout)
        cancellable.cancel()
    }
    
    /// Expects the receiving publisher to complete with a failure within the provided timeout.
    ///
    /// This operator will subscribe to the publisher chain and "block" the running test till the expectation is completed or thet timeout ellapses.
    /// - precondition: `timeout` must be greater than or equal to zero.
    /// - parameter timeout: The maximum amount of seconds that the test will wait. It must be greater or equal to zero.
    /// - parameter test: The test were the expectation shall be fulfilled.
    /// - parameter description: The expectation description.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    public func expectsFailure(timeout: TimeInterval, on test: XCTWaiterDelegate, _ description: String = "The publisher completes with failure", file: StaticString = #file, line: UInt = #line) {
        precondition(timeout >= 0)
        let exp = XCTestExpectation(description: description)
        
        let cancellable = self.sink(receiveCompletion: {
            switch $0 {
            case .finished: XCTFail("The publisher completed successfully when a failure was expected", file: file, line: line)
            case .failure(_): exp.fulfill()
            }
        }, receiveValue: { (_) in return })
        
        let waiter = XCTWaiter(delegate: test)
        waiter.wait(for: [exp], timeout: timeout)
        cancellable.cancel()
    }
    
    /// Expects the receiving publisher to produce a single value and then complete within the provided timeout.
    ///
    /// This operator will subscribe to the publisher chain and "block" the running test till the expectation is completed or thet timeout ellapses.
    /// - precondition: `timeout` must be greater than or equal to zero.
    /// - parameter timeout: The maximum amount of seconds that the test will wait. It must be greater or equal to zero.
    /// - parameter test: The test were the expectation shall be fulfilled.
    /// - parameter description: The expectation description.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - returns: The value forwarded by the publisher.
    @discardableResult public func expectsOne(timeout: TimeInterval, on test: XCTWaiterDelegate, _ description: String = "The publisher emits a single value and then completes successfully", file: StaticString = #file, line: UInt = #line) -> Self.Output {
        precondition(timeout >= 0)
        let exp = XCTestExpectation(description: description)
        
        var result: Self.Output? = nil
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .failure(let e):
                return XCTFail("The publisher completed with failure when successfull completion was expected\n\(e)\n", file: file, line: line)
            case .finished:
                guard case .some = result else {
                    return XCTFail("The publisher completed without outputting any value", file: file, line: line)
                }
                exp.fulfill()
            }
        }, receiveValue: {
            guard case .none = result else {
                cancellable?.cancel()
                cancellable = nil
                return XCTFail("The publisher produced more than one value when only one was expected", file: file, line: line)
            }
            result = $0
        })
        
        let waiter = XCTWaiter(delegate: test)
        waiter.wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
        return result!
    }
    
    /// Expects the receiving publisher to produce zero, one, or many values and then complete within the provided timeout.
    ///
    /// This operator will subscribe to the publisher chain and "block" the running test till the expectation is completed or thet timeout ellapses.
    /// - precondition: `timeout` must be greater than or equal to zero.
    /// - parameter timeout: The maximum amount of seconds that the test will wait. It must be greater or equal to zero.
    /// - parameter test: The test were the expectation shall be fulfilled.
    /// - parameter description: The expectation description.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - returns: The forwarded values by the publisher (it can be empty).
    @discardableResult public func expectsAll(timeout: TimeInterval, on test: XCTWaiterDelegate, _ description: String = "The publisher emits zero or more value and then completes successfully", file: StaticString = #file, line: UInt = #line) -> [Self.Output] {
        precondition(timeout >= 0)
        let exp = XCTestExpectation(description: description)
        
        var result: [Self.Output] = []
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished:
                exp.fulfill()
            case .failure(let e):
                XCTFail("The publisher completed with failure when successfull completion was expected\n\(e)\n", file: file, line: line)
                fatalError()
            }
        }, receiveValue: { result.append($0) })
        
        let waiter = XCTWaiter(delegate: test)
        waiter.wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
        return result
    }
    
    /// Expects the receiving publisher to produce at least a given number of values. Once the publisher has produced the given amount of values, it will get cancel by this function.
    ///
    /// This operator will subscribe to the publisher chain and "block" the running test till the expectation is completed or thet timeout ellapses.
    /// - precondition: `values` must be greater than zero.
    /// - precondition: `timeout` must be greater than or equal to zero.
    /// - parameter timeout: The maximum amount of seconds that the test will wait. It must be greater or equal to zero.
    /// - parameter test: The test were the expectation shall be fulfilled.
    /// - parameter description: The expectation description.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter check: The closure to be executed per value received.
    /// - returns: An array of all the values forwarded by the publisher.
    @discardableResult public func expectsAtLeast(values: Int, timeout: TimeInterval, on test: XCTWaiterDelegate, _ description: String = "The publisher emits at least the given amount of values and then completes successfully", file: StaticString = #file, line: UInt = #line, foreach check: ((Output)->Void)? = nil) -> [Self.Output] {
        precondition(values > 0 && timeout >= 0)
        
        let exp = XCTestExpectation(description: "Waiting for \(values) values")
        
        var result: [Self.Output] = []
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: if result.count == values { return exp.fulfill() }
            case .failure(let e): XCTFail(String(describing: e), file: file, line: line)
            }
        }, receiveValue: { (output) in
            guard result.count < values else { return }
            result.append(output)
            check?(output)
            guard result.count == values else { return }
            cancellable?.cancel()
            cancellable = nil
            exp.fulfill()
        })
        
        let waiter = XCTWaiter(delegate: test)
        waiter.wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
        return result
    }
}

#endif
