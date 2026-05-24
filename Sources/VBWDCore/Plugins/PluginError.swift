/// Plugin lifecycle errors. Mirrors the failure modes of `PluginRegistry.ts`.
public enum PluginError: Error, Equatable {
    case invalidVersion(String)
    case duplicate(String)
    case missingDependency(plugin: String, dependency: String)
    case unsatisfiedVersion(plugin: String, dependency: String, constraint: String)
    case circularDependency([String])
    case invalidState(plugin: String, message: String)
    case installFailed(plugin: String, message: String)
}
