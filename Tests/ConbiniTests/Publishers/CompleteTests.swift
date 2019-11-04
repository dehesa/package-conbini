import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Complete` publisher.
final class CompleteTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }

    static var allTests = [
        ("testSuccessfulCompletion", testSuccessfulCompletion),
        ("testFailedCompletion", testFailedCompletion),
        ("testSuccessfulNeverCompletion", testSuccessfulNeverCompletion),
        ("testFailedNeverCompletion", testFailedNeverCompletion),
        ("testPublisherPipeline", testPublisherPipeline)
    ]
    
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension CompleteTests {
    /// Tests a successful completion of the `Complete` publisher.
    func testSuccessfulCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        Complete<Int,CustomError>(error: nil)
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a failure completion of the `Complete` publisher.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        
        Complete<Int,CustomError>(error: CustomError())
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }

    /// Tests a successful completion of the `Complete` publisher using the convenience `<Never,Never>` initializer.
    func testSuccessfulNeverCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        Complete()
            .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a failure completion of the `Complete` publisher using the convenience `<Never,Error>` initializer.
    func testFailedNeverCompletion() {
        let exp = self.expectation(description: "Publisher completes with a failure")
        
        Complete(error: CustomError())
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

        Complete<Int,CustomError>(error: nil)
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
