import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredValueTests` publisher.
final class DeferredValueTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }

    static var allTests = [
        ("testSuccessfulDelivery", testSuccessfulDelivery)
    ]
        
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension DeferredValueTests {
    /// Tests a successful delivery of an emitted value.
    func testSuccessfulDelivery() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let value = 42
        DeferredTryValue { value }
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The deffered value publisher has failed!") }
                exp.fulfill()
            }, receiveValue: { XCTAssertEqual($0, value) })
            .store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
    }
}
