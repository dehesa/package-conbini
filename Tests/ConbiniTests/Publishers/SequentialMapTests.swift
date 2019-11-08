import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `SequentialMap` publisher.
final class SequentialMapTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }

    static var allTests = [
        ("testAsyncMap", testAsyncMap),
        ("testAsyncTryMap", testAsyncTryMap),
        ("testSequentialMap", testSequentialMap),
        ("testAsyncMapFailure", testAsyncMapFailure),
        ("testAsyncTryMapFailure", testAsyncTryMapFailure),
        ("testSequentialMapFailure", testSequentialMapFailure)
    ]
}

extension SequentialMapTests {
    /// Test a "vanilla" map operation with the diferrence that is asynchronous.
    func testAsyncMap() {
        let exp = self.expectation(description: "Publisher completes")

        var received: [Int] = .init()
        [1, 2, 3, 4].publisher.asyncMap { (value, promise) in
            DispatchQueue.main.async { promise(value * 10) }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20, 30, 40])
    }
    
    /// Test a "vanilla" try map operation with the diferrence that is asynchronous.
    func testAsyncTryMap() {
        let exp = self.expectation(description: "Publisher completes")

        var received: [Int] = .init()
        [1, 2, 3, 4].publisher.asyncTryMap(failure: Swift.Error.self) { (value, promise) in
            DispatchQueue.main.async { promise(.success(value * 10)) }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20, 30, 40])
    }
    
    /// Test a sequntial multi-map operation with the diferrence that is asynchronous.
    func testSequentialMap() {
        let queue = DispatchQueue.main
        let exp = self.expectation(description: "Publisher completes")

        var received: [Int] = .init()
        [1, 2, 3, 4].publisher.sequentialMap { (value, promise) in
            queue.async { XCTAssertEqual(promise(value * 10 + 0, .continue), .allowed) }
            queue.async { XCTAssertEqual(promise(value * 10 + 1, .continue), .allowed) }
            queue.async { XCTAssertEqual(promise(value * 10 + 2, .finished), .forbidden) }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 11, 12, 20, 21, 22, 30, 31, 32, 40, 41, 42])
    }
        
    /// Test a "vanilla" map operation with the difference that is asynchronous an that it fails in the middle.
    func testAsyncMapFailure() {
        let queue = DispatchQueue.main
        let exp = self.expectation(description: "Publisher completes")

        let upstream = [
                Just(1).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Just(2).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Fail<Int,CustomError>(error: CustomError()).eraseToAnyPublisher(),
                Just(4).setFailureType(to: CustomError.self).eraseToAnyPublisher()
            ].publisher
            .setFailureType(to: CustomError.self)
            .sequentialFlatMap { $0 }

        var received: [Int] = .init()
        upstream.asyncMap { (value, promise) in
            queue.async { promise(value * 10) }
        }.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20])
    }
        
    /// Test a "vanilla" try map operation with the difference that is asynchronous an that it fails in the middle.
    func testAsyncTryMapFailure() {
        let queue = DispatchQueue.main
        let exp = self.expectation(description: "Publisher completes")

        let upstream = [
                Just(1).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Just(2).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Fail<Int,CustomError>(error: CustomError()).eraseToAnyPublisher(),
                Just(4).setFailureType(to: CustomError.self).eraseToAnyPublisher()
            ].publisher
            .setFailureType(to: CustomError.self)
            .sequentialFlatMap { $0 }

        var received: [Int] = .init()
        upstream.asyncTryMap(failure: Swift.Error.self) { (value, promise) in
            queue.async { promise(.success(value * 10)) }
        }.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20])
    }

    /// Test a sequential multi-map operation with the difference that is asynchronous an that it fails in the middle.
    func testSequentialMapFailure() {
        let queue = DispatchQueue.main
        let exp = self.expectation(description: "Publisher completes")

        let upstream = [
                Just(1).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Just(2).setFailureType(to: CustomError.self).eraseToAnyPublisher(),
                Fail<Int,CustomError>(error: CustomError()).eraseToAnyPublisher(),
                Just(4).setFailureType(to: CustomError.self).eraseToAnyPublisher()
            ].publisher
            .setFailureType(to: CustomError.self)
            .sequentialFlatMap { $0 }

        var received: [Int] = .init()
        upstream.sequentialMap { (value, promise) in
            queue.async { XCTAssertEqual(promise(value * 10 + 0, .continue), .allowed) }
            queue.async { XCTAssertEqual(promise(value * 10 + 1, .continue), .allowed) }
            queue.async { XCTAssertEqual(promise(value * 10 + 2, .finished), .forbidden) }
        }.sink(receiveCompletion: {
            guard case .failure = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 11, 12, 20, 21, 22])
    }
}
