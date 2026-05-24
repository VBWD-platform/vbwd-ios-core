/// Plugin lifecycle manager. Port of `PluginRegistry.ts`:
/// register → install (topological, semver-checked) → activate/deactivate
/// (active-dependent guarded) → uninstall, with **per-plugin error isolation**
/// — a third-party plugin failing its hook becomes `.error` without aborting
/// the rest (web parity, robustness).
@MainActor
public final class PluginRegistry {
    private final class Record {
        let plugin: Plugin
        var status: PluginStatus
        init(_ p: Plugin) { plugin = p; status = .registered }
    }

    private var records: [String: Record] = [:]
    private var registrationOrder: [String] = []

    public init() {}

    // MARK: Registration

    public func register(_ plugin: Plugin) throws {
        let name = plugin.metadata.name
        guard records[name] == nil else { throw PluginError.duplicate(name) }
        records[name] = Record(plugin)
        registrationOrder.append(name)
    }

    public func status(of name: String) -> PluginStatus? { records[name]?.status }

    public func all() -> [(name: String, status: PluginStatus)] {
        registrationOrder.compactMap { n in records[n].map { (n, $0.status) } }
    }

    // MARK: Install

    public func install(_ name: String, _ sdk: PlatformSDK) async throws {
        guard let rec = records[name] else {
            throw PluginError.missingDependency(plugin: name, dependency: name)
        }
        do {
            try await rec.plugin.install(sdk)
            rec.status = .installed
        } catch {
            rec.status = .error("\(error)")
            throw PluginError.installFailed(plugin: name, message: "\(error)")
        }
    }

    /// Installs registered plugins. `enabled` (manifest gate) restricts the set;
    /// nil means all registered. Structural problems (missing/unsatisfied/
    /// circular dependencies) throw up front (web parity). A plugin whose
    /// `install` hook throws is marked `.error` and skipped — others continue.
    public func installAll(_ sdk: PlatformSDK, enabled: Set<String>? = nil) async throws {
        let active = registrationOrder.filter { name in
            enabled.map { $0.contains(name) } ?? true
        }
        let activeSet = Set(active)

        // Validate dependencies against the gated set + semver.
        for name in active {
            let meta = records[name]!.plugin.metadata
            for dep in meta.dependencies.resolved {
                guard activeSet.contains(dep.name) else {
                    throw PluginError.missingDependency(plugin: name, dependency: dep.name)
                }
                let depVersion = records[dep.name]!.plugin.metadata.version
                guard dep.constraint.isSatisfied(by: depVersion) else {
                    throw PluginError.unsatisfiedVersion(
                        plugin: name, dependency: dep.name,
                        constraint: "\(depVersion)")
                }
            }
        }

        let ordered = try topologicalOrder(active)

        for name in ordered {
            let rec = records[name]!
            do {
                try await rec.plugin.install(sdk)
                rec.status = .installed
            } catch {
                rec.status = .error("\(error)")   // isolation: continue
            }
        }
    }

    // MARK: Activation

    public func activate(_ name: String) async throws {
        guard let rec = records[name] else {
            throw PluginError.invalidState(plugin: name, message: "not registered")
        }
        switch rec.status {
        case .installed, .inactive:
            break
        default:
            throw PluginError.invalidState(
                plugin: name, message: "must be installed or inactive to activate")
        }
        try await rec.plugin.activate()
        rec.status = .active
    }

    public func deactivate(_ name: String) async throws {
        guard let rec = records[name] else {
            throw PluginError.invalidState(plugin: name, message: "not registered")
        }
        // Block if an active plugin still depends on this one (web guard).
        for (other, otherRec) in records where otherRec.status == .active {
            if other != name,
               otherRec.plugin.metadata.dependencies.resolved.contains(where: { $0.name == name }) {
                throw PluginError.invalidState(
                    plugin: name,
                    message: "active dependent '\(other)' prevents deactivation")
            }
        }
        try await rec.plugin.deactivate()
        rec.status = .inactive
    }

    public func uninstall(_ name: String) async throws {
        guard let rec = records[name] else {
            throw PluginError.invalidState(plugin: name, message: "not registered")
        }
        try await rec.plugin.uninstall()
        rec.status = .registered
    }

    // MARK: Topological sort (DFS, on-stack cycle detection — web parity)

    private func topologicalOrder(_ names: [String]) throws -> [String] {
        var result: [String] = []
        var visited: Set<String> = []
        var onStack: [String] = []

        func visit(_ name: String) throws {
            if visited.contains(name) { return }
            if onStack.contains(name) {
                throw PluginError.circularDependency(onStack + [name])
            }
            onStack.append(name)
            let meta = records[name]!.plugin.metadata
            for dep in meta.dependencies.resolved where names.contains(dep.name) {
                try visit(dep.name)
            }
            onStack.removeLast()
            visited.insert(name)
            result.append(name)
        }

        for n in names { try visit(n) }
        return result
    }
}
