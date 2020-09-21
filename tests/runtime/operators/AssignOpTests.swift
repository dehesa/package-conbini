import XCTest
import Conbini
import Combine

/// Tests the correct behavior of the `assign(to:on:)` and `invoke(_:on:)` operators.
final class AssignOpTests: XCTestCase {
    /// A convenience storage of cancellables.
    private var _cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        self.continueAfterFailure = false
        self._cancellables.removeAll()
    }
}

extension AssignOpTests {
    /// Tests the `assign(to:onWeak:)` operations.
    func testRegularAssign() {
        let data = [1, 2, 3, 4]
        final class _Custom { var value: Int = 0 }
        
        let objA = _Custom()
        data.publisher.assign(to: \.value, on: objA).store(in: &self._cancellables)
        XCTAssert(objA.value == data.last!)

        let objB = _Custom()
        data.publisher.assign(to: \.value, onWeak: objB).store(in: &self._cancellables)
        XCTAssert(objB.value == data.last!)
        
        let objC = _Custom()
        data.publisher.assign(to: \.value, onWeak: objC).store(in: &self._cancellables)
        XCTAssert(objC.value == data.last!)
    }
    
    /// Tests the `invoke(_:on:)` operations.
    func testRegularInvocation() {
        let data = [1, 2, 3, 4]
        final class _Custom {
            private(set) var value: Int = 0
            func setNumber(value: Int) -> Void { self.value = value }
        }
        
        let objA = _Custom()
        data.publisher.invoke(_Custom.setNumber, on: objA).store(in: &self._cancellables)
        XCTAssert(objA.value == data.last!)
        
        let objB = _Custom()
        data.publisher.invoke(_Custom.setNumber, onWeak: objB).store(in: &self._cancellables)
        XCTAssert(objB.value == data.last!)
        
        let objC = _Custom()
        data.publisher.invoke(_Custom.setNumber, onWeak: objC).store(in: &self._cancellables)
        XCTAssert(objC.value == data.last!)
    }
}
