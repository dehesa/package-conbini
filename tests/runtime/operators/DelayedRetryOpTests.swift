import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Then` operator.
final class DelayedRetryOpTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }
}

extension DelayedRetryOpTests {
    /// Test a normal "happy path" example for the custom "delayed retry" operator.
    func testSuccessfulEnding() {
        let e = self.expectation(description: "Successful completion")
        
        let input = 0..<10
        var output = [Int]()
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests.operators.retry")
        
        let cancellable = input.publisher
            .map { $0 * 2 }
            .retry(on: queue, intervals: [0, 0.2, 0.5])
            .map { $0 * 2 }
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("A failure completion has been received, when a successful one was expected") }
                e.fulfill()
            }, receiveValue: { output.append($0) })
        
        self.wait(for: [e], timeout: 0.2)
        XCTAssertEqual(Array(input).map { $0 * 4 }, output)
        cancellable.cancel()
    }
    
    /// Tests a failure reception and successful recovery.
    func testSingleFailureRecovery() {
        let e = self.expectation(description: "Single failure recovery")
        
        let input = [0, 1, 2]
        var output = [Int]()
        var passes = 0
        var marker: (start: CFAbsoluteTime?, end: CFAbsoluteTime?) = (nil, nil)
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests.operators.retry")
        
        let cancellable = DeferredPassthrough<Int,CustomError> { (subject) in
                passes += 1
                if passes == 2 { marker.end = CFAbsoluteTimeGetCurrent() }
            
                subject.send(input[0])
                subject.send(input[1])
                subject.send(input[2])
            
                if passes == 1 {
                    marker.start = CFAbsoluteTimeGetCurrent()
                    subject.send(completion: .failure(CustomError()))
                } else {
                    subject.send(completion: .finished)
                }
            }.retry(on: queue, intervals: [0.2, 0.4, 0.6])
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("A failure completion has been received, when a successful one was expected") }
                e.fulfill()
            }, receiveValue: { output.append($0) })
        
        self.wait(for: [e], timeout: 0.6)
        XCTAssertEqual(passes, 2)
        XCTAssertEqual(input + input, output)
        XCTAssertGreaterThan(marker.end! - marker.start!, 0.2)
        cancellable.cancel()
    }
    
    /// Test publishing a stream of failure from which is impossible to recover.
    func testFailuresStream() {
        let e = self.expectation(description: "Failure stream")
        
        let intervals: [TimeInterval] = [0.1, 0.3, 0.5]
        var markers = [CFAbsoluteTime]()
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests.operators.retry")
        
        let cancellable = Deferred { Fail(outputType: Int.self, failure: CustomError()) }
            .handleEvents(receiveCompletion: {
                markers.append(CFAbsoluteTimeGetCurrent())
                guard case .failure = $0 else { return XCTFail("A success completion has been received, when a failure one was expected") }
            })
            .retry(on: queue, intervals: intervals)
            .sink(receiveCompletion: {
                markers.append(CFAbsoluteTimeGetCurrent())
                guard case .failure = $0 else { return XCTFail("A success completion has been received, when a failure one was expected") }
                e.fulfill()
            }, receiveValue: { _ in XCTFail("A value has been received when none were expected") })
        
        self.wait(for: [e], timeout: 3)
        XCTAssertEqual(markers.count, 5)
        XCTAssertGreaterThan(markers[1] - intervals[0], intervals[0])
        XCTAssertGreaterThan(markers[2] - intervals[1], intervals[1])
        XCTAssertGreaterThan(markers[3] - intervals[2], intervals[2])
        cancellable.cancel()
    }
}
