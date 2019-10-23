import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Complete` publisher.
final class CompleteTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }

    static var allTests = [
        ("testSuccessfulCompletion", testSuccessfulCompletion),
        ("testFailedCompletion", testFailedCompletion),
        ("testSuccessfulNeverCompletion", testSuccessfulNeverCompletion),
        ("testFailedNeverCompletion", testFailedNeverCompletion),
        ("testPublisherPipeline", testPublisherPipeline)
    ]
}

extension CompleteTests {
    /// Tests a successful completion of the `Complete` publisher.
    func testSuccessfulCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        let publisher = Complete<Int,CustomError>(error: nil)
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
        
        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }
    
    /// Tests a failure completion of the `Complete` publisher.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        let publisher = Complete<Int,CustomError>(error: CustomError())
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
        
        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }

    /// Tests a successful completion of the `Complete` publisher using the convenience `<Never,Never>` initializer.
    func testSuccessfulNeverCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        let publisher = Complete()
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
        
        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }
    
    /// Tests a failure completion of the `Complete` publisher using the convenience `<Never,Error>` initializer.
    func testFailedNeverCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        let publisher = Complete(error: CustomError())
        
        let cancellable = publisher.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
        
        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }

    /// Tests the correct resource dumping.
    func testPublisherPipeline() {
        let exp = self.expectation(description: "Publisher completes successfully")

        let publisher = Complete<Int,CustomError>(error: nil)
            .map { $0 * 2 }
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })

        let cancellable = publisher.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
            exp.fulfill()
        }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

        self.wait(for: [exp], timeout: 0.2)
        cancellable.cancel()
    }
}
