import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Then` operator.
final class HandleEndOpTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension HandleEndOpTests {
    /// Test a normal "happy path" example for the custom "then" combine operator.
    func testSuccessfulEnding() {
        let e = self.expectation(description: "Successful completion")
        
        let values = [0, 1, 2]
        var (received, isFinished) = ([Int](), false)
        
        let subject = PassthroughSubject<Int,CustomError>()
        let cancellable = subject
            .handleEnd {
                guard !isFinished else { return XCTFail("The end closure has been executed more than once") }
                
                switch $0 {
                case .none: XCTFail("A cancel event has been received, when a successful completion was expected")
                case .finished: isFinished = true
                case .failure: XCTFail("A failure completion has been received, when a successful one was expected")
                }
        }.sink(receiveCompletion: { _ in e.fulfill() }) { received.append($0) }
        
        let queue = DispatchQueue.main
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(values[0]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(200)) { subject.send(values[1]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(300)) { subject.send(completion: .finished) }
        queue.asyncAfter(deadline: .now() + .milliseconds(400)) { subject.send(values[2]) }
        
        self.wait(for: [e], timeout: 1)
        
        XCTAssertTrue(isFinished)
        XCTAssertEqual(received, values.dropLast())
        cancellable.cancel()
    }
    
    /// Tests the behavior of the `then` operator reacting to a upstream error.
    func testFailureEnding() {
        let e = self.expectation(description: "Failure completion")
        
        let values = [0, 1, 2]
        var (received, isFinished) = ([Int](), false)
        
        let subject = PassthroughSubject<Int,CustomError>()
        let cancellable = subject
            .handleEnd {
                guard !isFinished else { return XCTFail("The end closure has been executed more than once") }
                
                switch $0 {
                case .none: XCTFail("A cancel event has been received, when a failure completion was expected")
                case .finished: XCTFail("A successful completion has been received, when a failure one was expected")
                case .failure: isFinished = true
                }
        }.sink(receiveCompletion: { _ in e.fulfill() }) { received.append($0) }
        
        let queue = DispatchQueue.main
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(values[0]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(200)) { subject.send(values[1]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(300)) { subject.send(completion: .failure(CustomError())) }
        queue.asyncAfter(deadline: .now() + .milliseconds(400)) { subject.send(values[2]) }
        
        self.wait(for: [e], timeout: 1)
        
        XCTAssertTrue(isFinished)
        XCTAssertEqual(received, values.dropLast())
        cancellable.cancel()
    }
    
    func testCancelEnding() {
        let eClosure = self.expectation(description: "Cancel completion on closure")
        let eTimeout = self.expectation(description: "Cancel completion on timeout")
        
        let values = [0, 1]
        var (received, isFinished) = ([Int](), false)
        
        let subject = PassthroughSubject<Int,CustomError>()
        let cancellable = subject
            .handleEnd {
                guard !isFinished else { return XCTFail("The end closure has been executed more than once") }
                
                switch $0 {
                case .none: isFinished = true
                case .finished: XCTFail("A successful completion has been received, when a cancellation was expected")
                case .failure: XCTFail("A failure completion has been received, when a cancellation was expected")
                }
                
                eClosure.fulfill()
        }.sink(receiveCompletion: { _ in XCTFail() }) { received.append($0) }
        
        let queue = DispatchQueue.main
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(values[0]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(200)) { subject.send(values[1]) }
        queue.asyncAfter(deadline: .now() + .milliseconds(300)) { cancellable.cancel() }
        queue.asyncAfter(deadline: .now() + .milliseconds(400)) { eTimeout.fulfill() }
        
        self.wait(for: [eClosure, eTimeout], timeout: 1)
        
        XCTAssertTrue(isFinished)
        XCTAssertEqual(received, values)
        cancellable.cancel()
    }
    
    func testAbruptEndings() {
        let e = self.expectation(description: "Abrupt completion")
        
        var isFinished = false
        let cancellable = Empty<Int,CustomError>(completeImmediately: true)
            .handleEnd {
                guard !isFinished else { return XCTFail("The end closure has been executed more than once") }
                
                switch $0 {
                case .none: XCTFail("A cancel event has been received, when a successful completion was expected")
                case .finished: isFinished = true
                case .failure: XCTFail("A failure completion has been received, when a successful one was expected")
                }
            }.sink(receiveCompletion: { (_) in e.fulfill() }, receiveValue: { _ in })
        
        self.wait(for: [e], timeout: 0.5)
        XCTAssertTrue(isFinished)
        cancellable.cancel()
    }
}
