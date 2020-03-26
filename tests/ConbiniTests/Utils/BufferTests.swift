import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `DeferredComplete` publisher.
final class BufferTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }
    
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
}

extension BufferTests {
    /// Tests the regular usage of a buffer operator.
    func testRegularUsage() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let input = [0, 1, 2, 3, 4]
        var output = [Int]()
        
        let subject = PassthroughSubject<Int,CustomError>()
        let subscriber = AnySubscriber<Int,CustomError>(receiveSubscription: { $0.request(.max(1)) }, receiveValue: {
            output.append($0)
            return .max(1)
        }, receiveCompletion: {
            guard case .finished = $0 else { return XCTFail("The publisher failed when a successful completion was expected")}
            exp.fulfill()
        })
        
        subject.map { $0 * 2 }
            .buffer(size: 10, prefetch: .keepFull, whenFull: .fatalError())
            .map { $0 * 2}
            .subscribe(subscriber)
            
        for i in input { subject.send(i) }
        subject.send(completion: .finished)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(input.map { $0 * 4 }, output)
    }
    
    /// Tests a buffer operator when it is filled till the *brim*.
    func testBrimUsage() {
        let exp = self.expectation(description: "Publisher completes successfully")
        
        let input = [0, 1, 2, 3, 4]
        var output = [Int]()
        
        let subject = PassthroughSubject<Int,CustomError>()
        subject.map { $0 * 2 }
            .buffer(size: input.count, prefetch: .keepFull, whenFull: .fatalError())
            .map { $0 * 2}
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail("The publisher failed when a successful completion was expected")}
                exp.fulfill()
            }, receiveValue: { output.append($0) })
            .store(in: &self.cancellables)
        
        for i in input { subject.send(i) }
        subject.send(completion: .finished)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(input.map { $0 * 4 }, output)
    }
}
