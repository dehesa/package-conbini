import XCTest
import Combine
import Conbini
import ConbiniForTesting

/// Tests the correct behavior of the *expectation* conveniences.
final class ExpectationsTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    
    override func setUp() {
        self.continueAfterFailure = false
    }

    static var allTests = [
        ("testCompletionExpectations", testCompletionExpectations),
        ("testFailedExpectations", testFailedExpectations),
        ("testSingleValueEmissionExpectations", testSingleValueEmissionExpectations),
        ("testAllEmissionExpectations", testAllEmissionExpectations),
        ("testAtLeastEmisionExpectations", testAtLeastEmisionExpectations)
    ]
}

extension ExpectationsTests {
    /// Tests successful completion expectations.
    func testCompletionExpectations() {
        [0, 2, 4, 6, 8].publisher.expectsCompletion(timeout: 0.2, on: self)
        
        DeferredPassthrough<Int,Never> { (subject) in
            subject.send(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(2) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40)) { subject.send(4) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) { subject.send(6) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { subject.send(completion: .finished) }
        }.expectsCompletion(timeout: 0.2, on: self)
    }
    
    /// Tests failure completion expectations.
    func testFailedExpectations() {
        Fail<Int,CustomError>(error: .init()).expectsFailure(timeout: 0.2, on: self)
        
        DeferredPassthrough<Int,CustomError> { (subject) in
            subject.send(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(2) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40)) { subject.send(4) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) { subject.send(6) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { subject.send(completion: .failure(CustomError())) }
        }.expectsFailure(timeout: 0.2, on: self)
    }
    
    /// Tests one single value emission expectations.
    func testSingleValueEmissionExpectations() {
        Just<Int>(0).expectsOne(timeout: 0.2, on: self)
        
        DeferredPassthrough<Int,CustomError> { (subject) in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { subject.send(completion: .failure(CustomError())) }
        }.expectsFailure(timeout: 0.2, on: self)
    }
    
    /// Tests the reception of all emitted values.
    func testAllEmissionExpectations() {
        let values = [0, 2, 4, 6, 8]
        
        let sequenceEmitted = values.publisher.expectsAll(timeout: 0.2, on: self)
        XCTAssertEqual(values, sequenceEmitted)
        
        let subjectEmitted = DeferredPassthrough<Int,CustomError> { (subject) in
            for (index, value) in values.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(index*10)) { subject.send(value) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(values.count*10)) { subject.send(completion: .finished) }
        }.expectsAll(timeout: 0.2, on: self)
        XCTAssertEqual(values, subjectEmitted)
    }
    
    /// Tests the reception of at least a given amount of values.
    func testAtLeastEmisionExpectations() {
        let values = [0, 2, 4, 6, 8]
        
        let sequenceEmitted = values.publisher.expectsAtLeast(values: 2, timeout: 0.2, on: self)
        XCTAssertEqual(.init(values[0..<2]), sequenceEmitted)
        
        let subjectEmitted = DeferredPassthrough<Int,CustomError> { (subject) in
            for (index, value) in values.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(index*10)) { subject.send(value) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(values.count*10)) { subject.send(completion: .finished) }
        }.expectsAtLeast(values: 2, timeout: 0.2, on: self)
        XCTAssertEqual(.init(values[0..<2]), subjectEmitted)
    }
}
