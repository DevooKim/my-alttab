import Foundation

/// Minimal assertion harness (XCTest is unavailable without Xcode).
/// Each test file registers test functions; main.swift runs them all and
/// exits non-zero on any failure.
final class TestRun {
    static let shared = TestRun()
    private(set) var passed = 0
    private(set) var failed = 0

    func expect(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("FAIL: \(message) (\(file):\(line))")
        }
    }

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #fileID, line: Int = #line) {
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("FAIL: \(message) — expected \(expected), got \(actual) (\(file):\(line))")
        }
    }

    func finish() -> Never {
        print("\(passed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }
}

func expect(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
    TestRun.shared.expect(condition, message, file: file, line: line)
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #fileID, line: Int = #line) {
    TestRun.shared.expectEqual(actual, expected, message, file: file, line: line)
}
