import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `await` operator.
final class AwaitOpTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension AwaitOpTests {
    /// Tests the `await` operator.
    func testAwait() {
        let publisher = Just("Hello")
            .delay(for: 1, scheduler: DispatchQueue.global())
        
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests.await")
        let cancellable = Just(())
            .delay(for: 10, scheduler: queue)
            .sink { XCTFail("The await test failed") }
        
        let greeting = publisher.await
        XCTAssertEqual(greeting, "Hello")
        
        cancellable.cancel()
    }
}
