/// HTTP verbs the SDK issues. Mirrors the web `ApiClient` surface
/// (get/post/put/patch/delete).
public enum HTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
