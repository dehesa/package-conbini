import XCTest

import ConbiniTests

var tests = [XCTestCaseEntry]()
tests += ConbiniTests.allTests()
tests += ConbiniForTesting.allTests()
XCTMain(tests)
