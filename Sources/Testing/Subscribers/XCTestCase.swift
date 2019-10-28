#if canImport(XCTest)
import XCTest
import Combine
import Foundation

extension XCTestCase {
    /// Locks the receiving test for `interval` seconds.
    /// - parameter interval: The number of seconds waiting (must be greater than zero).
    public func wait(seconds interval: TimeInterval) {
        precondition(interval > 0)
        
        let e = self.expectation(description: "Waiting for \(interval) seconds")
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
            $0.invalidate()
            e.fulfill()
        }
        
        self.wait(for: [e], timeout: interval)
        timer.invalidate()
    }
}

#endif
