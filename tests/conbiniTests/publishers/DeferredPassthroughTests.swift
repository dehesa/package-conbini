import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `Complete` publisher.
final class DeferredPassthroughTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var _cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self._cancellables.removeAll()
    }
    
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension DeferredPassthroughTests {
    /// Tests a successful completion of the `DeferredCompletion` publisher.
    func testSuccessfulCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let values: [Int] = [1, 2, 3, 4]
        var receivedValues: [Int] = []
        
        DeferredPassthrough<Int,CustomError> { (subject) in
                for i in values { subject.send(i) }
                subject.send(completion: .finished)
            }.sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The subject failed unexpectedly") }
                exp.fulfill()
            }, receiveValue: { receivedValues.append($0) })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.5)
        XCTAssertEqual(values, receivedValues)
    }
    
    /// Tests a failure completion of the `DeferredCompletion` publisher.
    func testFailedCompletion() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let values: [Int] = [1, 2, 3, 4]
        var receivedValues: [Int] = []
        
        DeferredPassthrough<Int,CustomError> { (subject) in
                for i in values { subject.send(i) }
                subject.send(completion: .failure(.init()))
            }.sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail("The subject succeeeded unexpectedly") }
                exp.fulfill()
            }, receiveValue: { receivedValues.append($0) })
            .store(in: &self._cancellables)
        
        self.wait(for: [exp], timeout: 0.5)
        XCTAssertEqual(values, receivedValues)
    }
    
    func testBackpressure() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let values: [Int] = [1, 2, 3, 4]
        var receivedValues: [Int] = []
        
        let oneByOneSubscriber = AnySubscriber<Int,CustomError>(receiveSubscription: {
            $0.request(.max(2))
        }, receiveValue: {
            receivedValues.append($0)
            return .none
        }, receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The subject failed unexpectedly") }
            exp.fulfill()
        })
        
        DeferredPassthrough<Int,CustomError> { (subject) in
                for i in values { subject.send(i) }
                subject.send(completion: .finished)
            }.subscribe(oneByOneSubscriber)
        
        self.wait(for: [exp], timeout: 100)
        XCTAssertEqual(.init(values.prefix(upTo: 2)), receivedValues)
    }
}
