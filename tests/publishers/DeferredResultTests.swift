#if !os(watchOS)
import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Complete` publisher.
final class DeferredResultTests: XCTestCase {
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

extension DeferredResultTests {
    /// Tests a successful completion of the `DeferredCompletion` publisher.
    func testSuccessfulCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        let value = 1
        
        DeferredResult<Int,CustomError> { .success(value) }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { XCTAssertEqual($0, value) })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a failure completion of the `DeferredCompletion` publisher.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        
        DeferredResult<Int,CustomError> { .failure(CustomError()) }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
}
#endif
