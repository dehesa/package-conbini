import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredComplete` publisher.
final class DeferredCompleteTests: XCTestCase {
  override func setUp() {
    self.continueAfterFailure = false
  }

  /// A custom error to send as a dummy.
  private struct _CustomError: Swift.Error {}
}

extension DeferredCompleteTests {
  /// Tests a successful completion of the publisher.
  func testSuccessfulEmptyCompletion() {
    let exp = self.expectation(description: "Publisher completes successfully")

    let cancellable = DeferredComplete<Int,_CustomError>()
      .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
      .sink(receiveCompletion: {
        guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
        exp.fulfill()
      }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

    self.wait(for: [exp], timeout: 0.2)
    cancellable.cancel()
  }

  /// Tests a successful closure completion.
  func testSuccessfulClosureCompletion() {
    let exp = self.expectation(description: "Publisher completes successfully")

    let cancellable = DeferredComplete<Int,_CustomError> { return nil }
      .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
      .sink(receiveCompletion: {
        guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
        exp.fulfill()
      }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

    self.wait(for: [exp], timeout: 0.2)
    cancellable.cancel()
  }

  /// Tests a failure completion from an autoclosure.
  func testFailedCompletion() {
    let exp = self.expectation(description: "Publisher completes with a failure")

    let cancellable = DeferredComplete<Int,_CustomError>(error: .init())
      .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
      .sink(receiveCompletion: {
        guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
        exp.fulfill()
      }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

    self.wait(for: [exp], timeout: 0.2)
    cancellable.cancel()
  }

  /// Tests a failure completion from the full-fledge closure.
  func testFailedClosureCompletion() {
    let exp = self.expectation(description: "Publisher completes with a failure")

    let cancellable = DeferredComplete(output: Int.self) { return _CustomError() }
      .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
      .sink(receiveCompletion: {
        guard case .failure = $0 else { return XCTFail("The failed completion publisher has completed successfully!") }
        exp.fulfill()
      }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

    self.wait(for: [exp], timeout: 0.2)
    cancellable.cancel()
  }

  /// Tests the correct resource dumping.
  func testPublisherPipeline() {
    let exp = self.expectation(description: "Publisher completes successfully")

    let cancellable = DeferredComplete<Int,_CustomError>()
      .map { $0 * 2 }
      .handleEvents(receiveCancel: { XCTFail("The publisher has cancelled before completion") })
      .sink(receiveCompletion: {
        guard case .finished = $0 else { return XCTFail("The successful completion publisher has failed!") }
        exp.fulfill()
      }, receiveValue: { _ in XCTFail("The empty complete publisher has emitted a value!") })

    self.wait(for: [exp], timeout: 0.2)
    cancellable.cancel()
  }
}
