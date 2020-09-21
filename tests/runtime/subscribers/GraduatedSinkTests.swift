import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Then` operator.
final class GraduatedSinkTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension GraduatedSinkTests {
    /// Tests a subscription with a graduated sink yielding some values and a successful completion.
    func testSuccessfulCompletion() {
        let e = self.expectation(description: "Successful completion")
        
        let input = (0..<10)
        var received = [Int]()
        
        let subscriber = Subscribers.GraduatedSink<Int,CustomError>(maxDemand: .max(3), receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("A failure completion was received when a successful completion was expected.")}
            e.fulfill()
        }, receiveValue: { received.append($0) })
        
        input.publisher.setFailureType(to: CustomError.self)
            .map { $0 * 2}
            .subscribe(subscriber)
        
        self.wait(for: [e], timeout: 1)
        XCTAssertEqual(input.map { $0 * 2 }, received)
        subscriber.cancel()
    }
    
    /// Tests a subscription with a graduated sink yielding some values and a failure completion.
    func testFailedCompletion() {
        let e = self.expectation(description: "Failure completion")
        
        let input = (0..<10)
        var received = [Int]()
        
        let subscriber = Subscribers.GraduatedSink<Int,CustomError>(maxDemand: .max(3), receiveCompletion: {
            guard case .failure = $0 else { return XCTFail("A succesful completion was received when a failure completion was expected.")}
            e.fulfill()
        }, receiveValue: { received.append($0) })
        
        let subject = PassthroughSubject<Int,CustomError>()
        subject.map { $0 * 2}
            .subscribe(subscriber)
        
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests.subscribers.graduatedSink")
        for i in input {
            queue.asyncAfter(deadline: .now() + .milliseconds(i * 50)) { subject.send(i) }
        }
        
        queue.asyncAfter(deadline: .now() + .milliseconds((input.last! + 1) * 50)) {
            subject.send(completion: .failure(CustomError()))
        }
        
        self.wait(for: [e], timeout: 4)
        XCTAssertEqual(input.map { $0 * 2 }, received)
        subscriber.cancel()
    }
}
