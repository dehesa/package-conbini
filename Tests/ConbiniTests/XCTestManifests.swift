import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CompleteTests.allTests),
        testCase(DeferredValueTests.allTests),
    ]
}
#endif
