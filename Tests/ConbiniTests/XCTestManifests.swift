import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CompleteTests.allTests),
        testCase(DeferredValueTests.allTests),
        testCase(ThenOpTests.allTests)
    ]
}
#endif
