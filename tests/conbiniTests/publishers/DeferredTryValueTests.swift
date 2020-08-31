import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredTryValue` publisher.
final class DeferredTryValueTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var _cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self._cancellables.removeAll()
    }
    
    override func tearDown() {
        self._cancellables.removeAll()
    }
        
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension DeferredTryValueTests {
    /// Tests a successful delivery of an emitted value.
    func testSuccessfulDelivery() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let value = 42
        DeferredTryValue { value }
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The deffered value publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { XCTAssertEqual($0, value) })
            .store(in: &self._cancellables)

        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a failed value generation.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        
        DeferredTryValue { throw CustomError() }
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The deffered value publisher has completed successfully!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The deferred complete has emitted a value!") })
            .store(in: &self._cancellables)

        self.wait(for: [exp], timeout: 0.2)
    }
}
