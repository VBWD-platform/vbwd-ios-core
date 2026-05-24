import Foundation

/// `MAJOR.MINOR.PATCH` semantic version. Port of the version handling behind
/// the web `satisfiesVersion` used by `PluginRegistry.ts`.
public struct SemanticVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major; self.minor = minor; self.patch = patch
    }

    /// Parses `"1.2.3"`. Throws `PluginError.invalidVersion` otherwise.
    public init(parsing string: String) throws {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let a = Int(parts[0]), let b = Int(parts[1]), let c = Int(parts[2]),
              a >= 0, b >= 0, c >= 0 else {
            throw PluginError.invalidVersion(string)
        }
        self.init(a, b, c)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (l: SemanticVersion, r: SemanticVersion) -> Bool {
        (l.major, l.minor, l.patch) < (r.major, r.minor, r.patch)
    }
}

/// A dependency version constraint. Supports the npm-style operators the web
/// plugin registry accepts: `^`, `~`, `>=`, `>`, `<=`, `<`, `x`-ranges,
/// `*`/empty (any), and exact.
public struct VersionConstraint: Equatable, Sendable {
    private let raw: String

    public init(_ raw: String) {
        self.raw = raw.trimmingCharacters(in: .whitespaces)
    }

    public func isSatisfied(by v: SemanticVersion) -> Bool {
        let r = raw
        if r.isEmpty || r == "*" || r == "x" || r == "latest" { return true }

        if r.hasPrefix("^") { return caret(r.dropFirst(), v) }
        if r.hasPrefix("~") { return tilde(r.dropFirst(), v) }
        if r.hasPrefix(">=") { return (try? SemanticVersion(parsing: String(r.dropFirst(2).trimmed))).map { v >= $0 } ?? false }
        if r.hasPrefix("<=") { return (try? SemanticVersion(parsing: String(r.dropFirst(2).trimmed))).map { v <= $0 } ?? false }
        if r.hasPrefix(">")  { return (try? SemanticVersion(parsing: String(r.dropFirst(1).trimmed))).map { v >  $0 } ?? false }
        if r.hasPrefix("<")  { return (try? SemanticVersion(parsing: String(r.dropFirst(1).trimmed))).map { v <  $0 } ?? false }

        if r.contains("x") || r.contains("*") { return xRange(r, v) }

        // Exact match
        return (try? SemanticVersion(parsing: r)).map { v == $0 } ?? false
    }

    // ^1.2.3 → >=1.2.3 <2.0.0 ; ^0.2.3 → >=0.2.3 <0.3.0 ; ^0.0.3 → >=0.0.3 <0.0.4
    private func caret<S: StringProtocol>(_ s: S, _ v: SemanticVersion) -> Bool {
        guard let base = try? SemanticVersion(parsing: String(s).trimmed) else { return false }
        let upper: SemanticVersion
        if base.major > 0 { upper = SemanticVersion(base.major + 1, 0, 0) }
        else if base.minor > 0 { upper = SemanticVersion(0, base.minor + 1, 0) }
        else { upper = SemanticVersion(0, 0, base.patch + 1) }
        return v >= base && v < upper
    }

    // ~1.2.3 → >=1.2.3 <1.3.0
    private func tilde<S: StringProtocol>(_ s: S, _ v: SemanticVersion) -> Bool {
        guard let base = try? SemanticVersion(parsing: String(s).trimmed) else { return false }
        return v >= base && v < SemanticVersion(base.major, base.minor + 1, 0)
    }

    // 1.x / 1.2.x / 1.* — fixed prefix, wildcard tail
    private func xRange(_ s: String, _ v: SemanticVersion) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        func isWild(_ p: String) -> Bool { p == "x" || p == "*" || p.isEmpty }
        guard let maj = Int(parts.first ?? "") else { return false }
        if maj != v.major { return false }
        if parts.count >= 2 {
            if isWild(parts[1]) { return true }
            guard let mn = Int(parts[1]), mn == v.minor else { return false }
        }
        if parts.count >= 3 {
            if isWild(parts[2]) { return true }
            guard let pt = Int(parts[2]), pt == v.patch else { return false }
        }
        return true
    }
}

private extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
