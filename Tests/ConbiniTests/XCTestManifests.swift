import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ResultOpTests.allTests),
        testCase(ThenOpTests.allTests),
        
        testCase(CompleteTests.allTests),
        testCase(DeferredCompleteTests.allTests),
        testCase(DeferredResultTests.allTests),
        testCase(DeferredValueTests.allTests),
        testCase(SequentialFlatMapTests.allTests),
        testCase(SequentialMapTests.allTests),
    ]
}
#endif
