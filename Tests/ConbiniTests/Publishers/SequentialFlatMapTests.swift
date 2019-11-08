import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `SequentialFlatMap` publisher.
final class SequentialFlatMapTests: XCTestCase {
    /// A custom error to send as a dummy.
    private struct CustomError: Swift.Error {}
    /// A convenience storage of cancellables.
    private var cancellables: Set<AnyCancellable> = .init()

    override func setUp() {
        self.continueAfterFailure = false
        self.cancellables = .init()
    }

    static var allTests = [
        ("testSimpleChild", testSimpleChild),
        ("testSequentialChildren", testSequentialChildren),
        ("testBackpressureWithSupport", testBackpressureWithSupport),
        ("testBackpressureWithoutSupport", testBackpressureWithoutSupport),
        ("testBackpressureWithBuffer", testBackpressureWithBuffer),
        ("testFailureForwarding", testFailureForwarding)
    ]
}

extension SequentialFlatMapTests {
    /// Tests a simple sequence publisher child.
    func testSimpleChild() {
        typealias Child = Publishers.Sequence<ClosedRange<Int>,Never>
        let value = (0...9)
        
        let exp = self.expectation(description: "Downstream must complete")
        let upstream = PassthroughSubject<Child,Never>()
        upstream.sequentialFlatMap { $0 }.collect().sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            XCTAssertEqual($0, Array(value))
        }).store(in: &self.cancellables)
        
        upstream.send(value.publisher)
        upstream.send(completion: .finished)
        self.wait(for: [exp], timeout: 0.2)
    }

    /// Tests a sequential arrival of children publishers.
    func testSequentialChildren() {
        typealias Child = AnyPublisher<Int,Never>
        let upstream = PassthroughSubject<Child,Never>()

        let exp = self.expectation(description: "Downstream must complete")
        upstream.sequentialFlatMap { $0 }.collect().sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            XCTAssertEqual($0, Array(0...19))
        }).store(in: &self.cancellables)

        let (queue, now) = (DispatchQueue.main, DispatchTime.now())
        queue.asyncAfter(deadline: now + .milliseconds(10)) {
            upstream.send(Just(0).eraseToAnyPublisher())
        }
        queue.asyncAfter(deadline: now + .milliseconds(20)) {
            upstream.send((1...9).publisher.eraseToAnyPublisher())
        }
        queue.asyncAfter(deadline: now + .milliseconds(50)) {
            upstream.send(Empty<Int,Never>(completeImmediately: true).eraseToAnyPublisher())
        }
        queue.asyncAfter(deadline: now + .milliseconds(60)) {
            upstream.send((10...15).publisher.eraseToAnyPublisher())
        }
        queue.asyncAfter(deadline: now + .milliseconds(100)) {
            let subject = PassthroughSubject<Int,Never>()
            queue.asyncAfter(deadline: now + .milliseconds(110)) {
                subject.send(16)
                subject.send(17)
            }
            queue.asyncAfter(deadline: now + .milliseconds(130)) {
                subject.send(18)
            }
            queue.asyncAfter(deadline: now + .milliseconds(140)) {
                subject.send(19)
            }
            queue.asyncAfter(deadline: now + .milliseconds(150)) {
                subject.send(completion: .finished)
            }
            return upstream.send(subject.eraseToAnyPublisher())
        }
        queue.asyncAfter(deadline: now + .milliseconds(180)) {
            upstream.send(completion: .finished)
        }
        self.wait(for: [exp], timeout: 1)
    }

    /// Tests the "burst" arrival of children publishers from a publisher that supports backpressure.
    func testBackpressureWithSupport() {
        let queue = DispatchQueue.main

        let upstream = (0...5).map { i in
            DeferredPassthrough<Int,Never> { (subject) in
                queue.asyncAfter(deadline: .now() + .milliseconds(10)) { subject.send(i*5) }
                queue.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(i*5 + 1) }
                queue.asyncAfter(deadline: .now() + .milliseconds(30)) { subject.send(i*5 + 2) }
                queue.asyncAfter(deadline: .now() + .milliseconds(40)) { subject.send(i*5 + 3) }
                queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(i*5 + 4) }
                queue.asyncAfter(deadline: .now() + .milliseconds(60)) { subject.send(completion: .finished) }
            }
        }.publisher

        let exp = self.expectation(description: "Downstream must complete")
        upstream.sequentialFlatMap { $0 }.collect().sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            XCTAssertEqual($0, Array(0..<30))
        }).store(in: &self.cancellables)

        self.wait(for: [exp], timeout: 0.5)
    }

    /// Test the operator behavior when a barrage of child publishers is sent without a buffer.
    func testBackpressureWithoutSupport() {
        let queue = DispatchQueue.main

        let upstream = PassthroughSubject<AnyPublisher<Int,Never>,Never>()

        let exp = self.expectation(description: "Downstream must complete")
        upstream.sequentialFlatMap { $0 }.collect().sink(receiveCompletion: {
            guard case .finished = $0 else { return XCTFail() }
            exp.fulfill()
        }, receiveValue: {
            XCTAssertNotEqual($0, Array(0..<30))
        }).store(in: &self.cancellables)

        for i in 0...5 {
            let child = DeferredPassthrough<Int,Never> { (subject) in
                queue.asyncAfter(deadline: .now() + .milliseconds(10)) { subject.send(i*5) }
                queue.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(i*5 + 1) }
                queue.asyncAfter(deadline: .now() + .milliseconds(30)) { subject.send(i*5 + 2) }
                queue.asyncAfter(deadline: .now() + .milliseconds(40)) { subject.send(i*5 + 3) }
                queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(i*5 + 4) }
                queue.asyncAfter(deadline: .now() + .milliseconds(60)) { subject.send(completion: .finished) }
            }.eraseToAnyPublisher()
            upstream.send(child)
        }
        upstream.send(completion: .finished)

        self.wait(for: [exp], timeout: 0.5)
    }

    /// Test the operator behavior when a intermediate buffer is used.
    func testBackpressureWithBuffer() {
        let queue = DispatchQueue.main

        let upstream = PassthroughSubject<AnyPublisher<Int,Never>,Never>()

        let exp = self.expectation(description: "Downstream must complete")
        upstream.buffer(size: 50, prefetch: .keepFull, whenFull: .dropNewest)
            .sequentialFlatMap { $0 }.collect().sink(receiveCompletion: {
                guard case .finished = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: {
                XCTAssertEqual($0, Array(0..<30))
            }).store(in: &self.cancellables)

        for i in 0...5 {
            let child = DeferredPassthrough<Int,Never> { (subject) in
                queue.asyncAfter(deadline: .now() + .milliseconds(10)) { subject.send(i*5) }
                queue.asyncAfter(deadline: .now() + .milliseconds(20)) { subject.send(i*5 + 1) }
                queue.asyncAfter(deadline: .now() + .milliseconds(30)) { subject.send(i*5 + 2) }
                queue.asyncAfter(deadline: .now() + .milliseconds(40)) { subject.send(i*5 + 3) }
                queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(i*5 + 4) }
                queue.asyncAfter(deadline: .now() + .milliseconds(60)) { subject.send(completion: .finished) }
            }.eraseToAnyPublisher()
            upstream.send(child)
        }
        upstream.send(completion: .finished)

        self.wait(for: [exp], timeout: 0.5)
    }

    /// Tests the failure forwarding.
    func testFailureForwarding() {
        let exp = self.expectation(description: "Stream fails")

        typealias Child = DeferredResult<Int,CustomError>
        let upstream = PassthroughSubject<Child,CustomError>()
        upstream.buffer(size: 20, prefetch: .keepFull, whenFull: .dropNewest)
            .sequentialFlatMap { $0 }
            .sink(receiveCompletion: {
                guard case .failure = $0 else { return XCTFail() }
                exp.fulfill()
            }, receiveValue: { _ in return })
            .store(in: &self.cancellables)

        upstream.send(Child { .success(0)} )
        upstream.send(Child { .failure(CustomError()) })
        upstream.send(Child { .success(1)} )
        self.wait(for: [exp], timeout: 0.2)
    }
}
