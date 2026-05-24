/// Permission wildcard matcher. Exact port of the web
/// `hasUserPermission` / `hasAnyUserPermission` rules from `auth.ts`:
///   - `"*"`            grants everything
///   - exact match      grants
///   - `"shop.*"`       grants any permission with prefix `"shop."`
///
/// Single definition of the rule (DRY); takes `[String]`, not `AuthUser` (ISP).
public struct PermissionEvaluator: Sendable {
    public init() {}

    public func has(_ permission: String, in granted: [String]) -> Bool {
        if granted.contains("*") { return true }
        if granted.contains(permission) { return true }
        return granted.contains { g in
            g.hasSuffix(".*") && permission.hasPrefix(String(g.dropLast()))
        }
    }

    public func hasAny(_ permissions: [String], in granted: [String]) -> Bool {
        if granted.contains("*") { return true }
        return permissions.contains { has($0, in: granted) }
    }
}
