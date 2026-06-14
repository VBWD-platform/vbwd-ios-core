import Foundation

/// Observable unread-style counter a plugin attaches to its `MenuItem`
/// (S67.2 §3.4). `@Published Int` by deliberate decision (§8.3) — SwiftUI
/// ergonomics over an AsyncSequence. The side menu renders a red pill while
/// `count > 0`.
@MainActor
public final class BadgeProvider: ObservableObject {
    @Published public var count: Int

    public init(count: Int = 0) {
        self.count = count
    }
}
