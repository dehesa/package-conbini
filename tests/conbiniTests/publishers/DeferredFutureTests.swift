import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredComplete` publisher.
final class DeferredFutureTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var _cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self._cancellables.removeAll()
    }
    
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension DeferredFutureTests {
    /// Tests a successful completion of the publisher.
    func testSuccessfulSyncCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let value = 42
        DeferredFuture<Int,CustomError> { (promise) in
                promise(.success(value))
            }.handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { XCTAssertEqual($0, value) })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a successful completion of the publisher.
    func testSuccessfulAsyncCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let value = 42
        DeferredFuture<Int,CustomError> { (promise) in
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) { promise(.success(value)) }
            }.handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { XCTAssertEqual($0, value) })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a successful completion of the publisher.
    func testSuccessfulSyncFailure() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        DeferredFuture<Int,CustomError> { (promise) in
                promise(.failure(CustomError()))
            }.handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The failure deferred future publisher has succeeded!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("No value was expected") })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
    
    /// Tests a successful completion of the publisher.
    func testSuccessfulAsyncFailure() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        DeferredFuture<Int,CustomError> { (promise) in
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) { promise(.failure(CustomError())) }
            }.handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The failure deferred future publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { _ in XCTFail("No value was expected") })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
    }
}
