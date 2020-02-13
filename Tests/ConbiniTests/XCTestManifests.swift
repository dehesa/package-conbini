import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HandleEndOpTests.allTests),
        testCase(ResultOpTests.allTests),
        testCase(ThenOpTests.allTests),
        
        testCase(DeferredCompleteTests.allTests),
        testCase(DeferredFutureTests.allTests),
        testCase(DeferredPassthroughTests.allTests),
        testCase(DeferredResultTests.allTests),
        testCase(DeferredTryCompleteTests.allTests),
        testCase(DeferredTryValueTests.allTests),
        testCase(DeferredValueTests.allTests),
        testCase(SequentialMapTests.allTests),
    ]
}
#endif
