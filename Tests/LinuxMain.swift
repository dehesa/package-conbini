//// LinuxMain.swift
//fatalError("Run the tests with `swift test --enable-test-discovery`.")
import XCTest
import ConbiniTests

var tests = [XCTestCaseEntry]()
tests += ConbiniTests.allTests()
tests += ConbiniForTesting.allTests()
XCTMain(tests)
