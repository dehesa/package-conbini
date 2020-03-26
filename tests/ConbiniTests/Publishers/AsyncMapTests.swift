import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `AsyncMap` publisher.
final class AsyncMapTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    /// A convenience storage of cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables.removeAll()
    }
}

extension AsyncMapTests {
    /// Test async unlimited map operation (just one value asynchronous transformation).
    func testAsyncMapUnlimitedSingleValue() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        Just(1).asyncMap(parallel: .unlimited) { (value, isCancelled, promise) in
                queue.async {
                    XCTAssertFalse(isCancelled())
                    XCTAssertEqual(promise(value * 10, .finished), .forbidden)
                    XCTAssertTrue(isCancelled())
                }
            }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], 10)
    }
    
    /// Test async unlimited map operation (array of asynchronous transformation).
    func testAsyncMapUnlimitedArray() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()

        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncMap(parallel: .unlimited) { (value, isCancelled, promise) in
                queue.async {
                    XCTAssertFalse(isCancelled())
                    XCTAssertEqual(promise(value * 10, .finished), .forbidden)
                    XCTAssertTrue(isCancelled())
                }
            }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.sorted(), [10, 20, 30, 40].sorted())
    }
    
    /// Tests async unlimited map operation (each value received generate several values).
    func testAsyncMapUnlimitedMulti() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests", autoreleaseFrequency: .never, target: nil)
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncMap(parallel: .unlimited) { (value, _, promise) in
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
    
    /// Tests async restrict map operation (array of asynchronous transformation).
    func testAsyncMapRestrictedArrayOne() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncMap(parallel: .max(1)) { (value, _, promise) in
                queue.async { XCTAssertEqual(promise(value * 10, .finished), .forbidden) }
            }.sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20, 30, 40])
    }
    
    func testAsyncMapRestrictedArrayTwo() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        [1, 2, 3, 4, 5, 6, 7, 8].publisher
            .asyncMap(parallel: .max(2)) { (value, _, promise) in
                queue.async { XCTAssertEqual(promise(value * 10, .finished), .forbidden) }
        }.receive(on: DispatchQueue.main)
        .sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.sorted(), [10, 20, 30, 40, 50, 60, 70, 80].sorted())
    }
    
    /// Tests async unlimited map operation (each value received generate several values).
    func testAsyncMapRestrictedMulti() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests", autoreleaseFrequency: .never, target: nil)
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncMap(parallel: .max(1)) { (value, _, promise) in
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
}

extension AsyncMapTests {
    /// Test async unlimited map operation (just one value asynchronous transformation).
    func testAsyncTryMapUnlimitedSingleValue() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        Just(1).asyncTryMap(parallel: .unlimited) { (value, _, promise) in
            queue.async { XCTAssertEqual(promise(.success((value * 10, .finished))), .forbidden) }
        }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], 10)
    }
    
    /// Test async unlimited map operation (array of asynchronous transformation).
    func testAsyncTryMapUnlimitedArray() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncTryMap(parallel: .unlimited) { (value, _, promise) in
                queue.async { XCTAssertEqual(promise(.success((value * 10, .finished))), .forbidden) }
        }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.sorted(), [10, 20, 30, 40].sorted())
    }
    
    /// Tests async unlimited map operation (each value received generate several values).
    func testAsyncTryMapUnlimitedMulti() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests", autoreleaseFrequency: .never, target: nil)
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncTryMap(parallel: .unlimited) { (value, _, promise) in
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 0, .continue))), .allowed) }
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 1, .continue))), .allowed) }
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 2, .finished))), .forbidden) }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 11, 12, 20, 21, 22, 30, 31, 32, 40, 41, 42])
    }
    
    /// Tests async unlimited map operation (where one single error is published).
    func testAsyncTryMapUnlimitedError() {
        let exp = self.expectation(description: "Publisher fails")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        Just(1).asyncTryMap(parallel: .unlimited) { (value, isCancelled, promise) in
            queue.async {
                XCTAssertFalse(isCancelled())
                XCTAssertEqual(promise(.failure(CustomError())), .forbidden)
                XCTAssertTrue(isCancelled())
            }
        }.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard case .failure(let error) = $0, error is CustomError else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertTrue(received.isEmpty)
    }
    
    /// Tests async restrict map operation (array of asynchronous transformation).
    func testAsyncTryMapRestrictedArrayOne() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncTryMap(parallel: .max(1)) { (value, _, promise) in
                queue.async {
                    XCTAssertEqual(promise(.success((value * 10, .finished))), .forbidden)
                }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 20, 30, 40])
    }
    
    func testAsyncTryMapRestrictedArrayTwo() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue.global()
        
        var received: [Int] = .init()
        [1, 2, 3, 4, 5, 6, 7, 8].publisher
            .asyncTryMap(parallel: .max(2)) { (value, _, promise) in
                queue.async {
                    XCTAssertEqual(promise(.success((value * 10, .finished))), .forbidden)
                }
        }.receive(on: DispatchQueue.main)
        .sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: { received.append($0) })
            .store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received.sorted(), [10, 20, 30, 40, 50, 60, 70, 80].sorted())
    }
    
    /// Tests async unlimited map operation (each value received generate several values).
    func testAsyncTryMapRestrictedMulti() {
        let exp = self.expectation(description: "Publisher completes")
        let queue = DispatchQueue(label: "io.dehesa.conbini.tests", autoreleaseFrequency: .never, target: nil)
        
        var received: [Int] = .init()
        [1, 2, 3, 4].publisher
            .asyncTryMap(parallel: .max(1)) { (value, _, promise) in
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 0, .continue))), .allowed) }
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 1, .continue))), .allowed) }
                queue.async { XCTAssertEqual(promise(.success((value * 10 + 2, .finished))), .forbidden) }
        }.sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            received.append($0)
        }).store(in: &self.cancellables)
        
        self.wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(received, [10, 11, 12, 20, 21, 22, 30, 31, 32, 40, 41, 42])
    }
}
