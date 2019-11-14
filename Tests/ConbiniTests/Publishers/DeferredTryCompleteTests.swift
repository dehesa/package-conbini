import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredTryComplete` publisher.
final class DeferredTryCompleteTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }

    static var allTests = [
        ("testSuccessfulEmptyCompletion", testSuccessfulEmptyCompletion),
        ("testSuccessfulClosureCompletion", testSuccessfulClosureCompletion),
        ("testFailedCompletion", testFailedCompletion),
        ("testPublisherPipeline", testPublisherPipeline)
    ]
    
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension DeferredTryCompleteTests {
    /// Tests a successful completion of the publisher.
    func testSuccessfulEmptyCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        DeferredTryComplete<Int>()
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a successful closure completion.
    func testSuccessfulClosureCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        DeferredTryComplete<Int> { return }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a failure completion from the closure
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        
        DeferredTryComplete<Int> { throw CustomError() }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }

    /// Tests the correct resource dumping.
    func testPublisherPipeline() {
        let exp = self.expectation(description: "Publisher completes successfully")

        DeferredTryComplete<Int>()
            .map { $0 * 2 }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
    }
}
