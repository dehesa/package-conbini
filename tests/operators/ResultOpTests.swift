#if !os(watchOS)
import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `result(onEmpty:)` operator.
final class ResultOpTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    /// A convenience storage of cancellables.
    private var _cancellables: Set<AnyCancellable> = .init()
    
    override func setUp() {
        self.continueAfterFailure = false
        self._cancellables = .init()
    }
}

extension ResultOpTests {
    /// Test the `result` operator with completions and no values.
    func testCompletionWithoutValue() {
        Empty<Int,CustomError>(completeImmediately: true).result { _ in
            XCTFail("The handler has been called although it was not expected to")
        }.store(in: &self._cancellables)
        
        Empty<Int,CustomError>(completeImmediately: false).result { _ in
            XCTFail("The handler has been called although it was not expected to")
        }.store(in: &self._cancellables)
    }
    
    /// Tests the `result` operator with one value and completion.
    func testRegularUsage() {
        let input = 9
        
        Just(input).result {
            guard case .success(let received) = $0 else { return XCTFail() }
            XCTAssertEqual(received, input)
        }.store(in: &self._cancellables)
        
        [input].publisher.result {
            guard case .success(let received) = $0 else { return XCTFail() }
            XCTAssertEqual(received, input)
        }.store(in: &self._cancellables)
        
        let exp = self.expectation(description: "Deferred passthrough provides a result")
        DeferredPassthrough<Int,CustomError> { (subject) in
            let queue = DispatchQueue.main
            queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(input) }
            queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(completion: .finished) }
        }.result {
            guard case .success(let received) = $0 else { return XCTFail() }
            XCTAssertEqual(received, input)
            exp.fulfill()
        }.store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests the `result` operator in failure situations.
    func testFailure() {
        Fail<Int,CustomError>(error: .init()).result {
            guard case .failure(_) = $0 else { return XCTFail() }
        }
        
        let expA = self.expectation(description: "A failure result is provided")
        DeferredPassthrough<Int,CustomError> { (subject) in
            let queue = DispatchQueue.main
            queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(completion: .failure(.init())) }
        }.result {
            guard case .failure(_) = $0 else { return XCTFail() }
            expA.fulfill()
        }.store(in: &self._cancellables)
        
        self.wait(for: [expA], timeout: 0.2)
    }
}
#endif
