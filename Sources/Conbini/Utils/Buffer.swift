import Combine

extension Publishers.BufferingStrategy {
    /// Unconditionally prints a given message and stops execution when the buffer exhaust its capacity.
    /// - parameter message: The string to print. The default is an empty string.
    /// - parameter file: The file name to print with `message`. The default is the file where this function is called.
    /// - parameter line: The line number to print along with `message`. The default is the line number where `fatalError()`
    public static func fatalError(_ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) ->  Self {
        Swift.fatalError(message(), file: file, line: line)
    }
}
