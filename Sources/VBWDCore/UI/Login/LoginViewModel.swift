import Foundation
import Combine

/// Login screen logic. Port of `Login.vue`. Holds all decisions so the View is
/// thin and this is unit-testable without rendering (SRP). Navigation is NOT
/// here — `RootView` owns it (web router parity).
@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let session: AuthSession

    public init(session: AuthSession) {
        self.session = session
    }

    public var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    public func submit() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        await session.signIn(email: email, password: password)
        if case let .error(message) = session.state {
            errorMessage = message
        }
        isLoading = false
    }
}
