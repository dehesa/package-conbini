import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Then` operator.
final class ThenOpTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension ThenOpTests {
    /// Test a normal "happy path" example for the custom "then" combine operator.
    func testThenPassthrough() {
        let e = self.expectation(description: "Successful completion")
        let queue = DispatchQueue.main
        
        let subject = PassthroughSubject<Int,CustomError>()
        let cancellable = subject.then {
            ["A", "B", "C"].publisher.setFailureType(to: CustomError.self)
        }.sink(receiveCompletion: { _ in e.fulfill() }) { _ in return }
        
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(0) }
        queue.asyncAfter(deadline: .now() + .milliseconds(200)) { subject.send(1) }
        queue.asyncAfter(deadline: .now() + .milliseconds(300)) { subject.send(2) }
        queue.asyncAfter(deadline: .now() + .milliseconds(400)) { subject.send(completion: .finished) }
        
        self.wait(for: [e], timeout: 1)
        cancellable.cancel()
    }
    
    /// Tests the behavior of the `then` operator reacting to a upstream error.
    func testThenFailure() {
        let e = self.expectation(description: "Failure on origin")
        let queue = DispatchQueue.main
        
        let subject = PassthroughSubject<Int,CustomError>()
        let cancellable = subject.then {
            Future<String,CustomError> { (promise) in
                queue.asyncAfter(deadline: .now() + .milliseconds(200)) { promise(.success("Completed")) }
            }
        }.sink(receiveCompletion: { (completion) in
            guard case .failure = completion else { return }
            e.fulfill()
        }) { _ in return }
        
        queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(0) }
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(completion: .failure(CustomError())) }
        
        self.wait(for: [e], timeout: 2)
        cancellable.cancel()
    }
}
