//import XCTest
//import Conbini
//import Combine
//
///// Tests the correct behavior of the `AsyncMap` operator suit.
//final class AsyncMapOpTests: XCTestCase {
//    /// A custom error to send as a dummy.
//    private struct CustomError: Swift.Error {}
//    /// A convenience storage of cancellables.
//    private var cancellables: Set<AnyCancellable> = .init()
//    
//    override func setUp() {
//        self.continueAfterFailure = false
//        self.cancellables = .init()
//    }
//
//    static var allTests = [
//        ("testAsyncMap", testAsyncMap)
//    ]
//}
//
//extension AsyncMapOpTests {
//    /// Test the "vanilla" `asyncMap` operator.
//    func testAsyncMap() {
////        let values: [Int] = .init()
////        (0..<10).publisher.asyncMap { (value, promise) in
////            promise(value + 1)
////        }.sink { (value) in
////
////        }
////        XCTAssertEqual(result, Array((1..<11)))
//    }
//}
