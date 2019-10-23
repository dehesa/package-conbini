import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Complete` publisher.
final class DeferredValueTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }

    static var allTests = [
        ("testSuccessfulDelivery", testSuccessfulDelivery),
        ("testFailedCompletion", testFailedCompletion)
    ]
}

extension DeferredValueTests {
    /// Tests a successful delivery of an emitted value.
    func testSuccessfulDelivery() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let value = 42
        let publisher = DeferredValue { value }
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The deffered value publisher has failed!") }
            exp.fulfill()
        }, receiveValue: { XCTAssertEqual($0, value) })

        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }
    
    /// Tests a failed value generation.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        let publisher = DeferredValue { throw CustomError() }
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail("The deffered value publisher has completed successfully!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The deferred complete has emitted a value!") })

        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }
}
