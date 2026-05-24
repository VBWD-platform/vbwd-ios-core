// VBWDCoreTestKit — a tiny, dependency-free test harness.
//
// Exists because this environment ships Command Line Tools only (no XCTest,
// no swift-testing macro plugin). It preserves the things the sprint cares
// about: named test cases, suites, assertions, and a non-zero exit on failure
// so CI / `swift run` gives a real Red/Green signal.

import Foundation

public struct TestFailure: Error { public let message: String }


public final class TestReporter: @unchecked Sendable {
    private var passed = 0
    private var failed = 0
    private var failures: [String] = []
    private var currentSuite = ""
    private var currentTest = ""

    public init() {}

    public func beginSuite(_ name: String) {
        currentSuite = name
        FileHandle.standardError.write(Data("\n▶ \(name)\n".utf8))
    }

    public func record(_ ok: Bool, _ message: @autoclosure () -> String,
                        file: String, line: Int) {
        if ok {
            passed += 1
        } else {
            failed += 1
            let loc = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
            failures.append("✗ [\(currentSuite)] \(currentTest) — \(message()) (\(loc))")
        }
    }

    func setCurrentTest(_ name: String) { currentTest = name }

    public func summary() -> Int32 {
        let line = "\n──────── \(passed) passed, \(failed) failed ────────\n"
        FileHandle.standardError.write(Data(line.utf8))
        for f in failures { FileHandle.standardError.write(Data((f + "\n").utf8)) }
        return failed == 0 ? 0 : 1
    }
}


public final class Suite: @unchecked Sendable {
    let name: String
    let reporter: TestReporter
    init(name: String, reporter: TestReporter) {
        self.name = name
        self.reporter = reporter
    }

    /// Run one named test. Failures are recorded, never abort the run, so one
    /// red test does not hide the rest (full Red picture every run).
    public func test(_ name: String, _ body: @escaping () async throws -> Void) async {
        reporter.setCurrentTest(name)
        FileHandle.standardError.write(Data("  • \(name)\n".utf8))
        do {
            try await body()
        } catch let f as TestFailure {
            reporter.record(false, f.message, file: #file, line: #line)
        } catch {
            reporter.record(false, "threw unexpected error: \(error)",
                            file: #file, line: #line)
        }
    }

    public func expect(_ cond: @autoclosure () -> Bool, _ msg: String = "",
                        file: String = #file, line: Int = #line) {
        reporter.record(cond(), msg.isEmpty ? "expectation failed" : msg,
                        file: file, line: line)
    }

    public func expectEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "",
                                          file: String = #file, line: Int = #line) {
        reporter.record(a == b,
                        msg.isEmpty ? "expected \(a) == \(b)" : msg,
                        file: file, line: line)
    }

    public func expectNil(_ v: Any?, _ msg: String = "",
                          file: String = #file, line: Int = #line) {
        reporter.record(v == nil, msg.isEmpty ? "expected nil, got \(v as Any)" : msg,
                        file: file, line: line)
    }

    public func expectNotNil(_ v: Any?, _ msg: String = "",
                             file: String = #file, line: Int = #line) {
        reporter.record(v != nil, msg.isEmpty ? "expected non-nil" : msg,
                        file: file, line: line)
    }

    public func expectThrows(_ body: @escaping () async throws -> Void, _ msg: String = "",
                             file: String = #file, line: Int = #line) async {
        do {
            try await body()
            reporter.record(false, msg.isEmpty ? "expected an error to be thrown" : msg,
                            file: file, line: line)
        } catch {
            reporter.record(true, "", file: file, line: line)
        }
    }

    public func expectNoThrow(_ body: @escaping () async throws -> Void, _ msg: String = "",
                              file: String = #file, line: Int = #line) async {
        do {
            try await body()
            reporter.record(true, "", file: file, line: line)
        } catch {
            reporter.record(false, msg.isEmpty ? "unexpected error: \(error)" : msg,
                            file: file, line: line)
        }
    }
}


public final class TestRunner: @unchecked Sendable {
    private let reporter = TestReporter()
    private var suites: [(String, (Suite) async -> Void)] = []

    public init() {}

    public func suite(_ name: String, _ body: @escaping (Suite) async -> Void) {
        suites.append((name, body))
    }

    /// Runs every registered suite and returns a process exit code.
    public func run() async -> Int32 {
        for (name, body) in suites {
            reporter.beginSuite(name)
            let s = Suite(name: name, reporter: reporter)
            await body(s)
        }
        return reporter.summary()
    }
}

/// Resolves a path inside the test fixtures directory, independent of CWD.
public func fixturePath(_ name: String, file: String = #file) -> String {
    // .../Sources/VBWDCoreTestKit/TestKit.swift -> package root
    let pkgRoot = URL(fileURLWithPath: file)
        .deletingLastPathComponent()  // VBWDCoreTestKit
        .deletingLastPathComponent()  // Sources
        .deletingLastPathComponent()  // package root
    return pkgRoot
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
        .path
}

public func loadFixture(_ name: String) throws -> Data {
    try Data(contentsOf: URL(fileURLWithPath: fixturePath(name)))
}
