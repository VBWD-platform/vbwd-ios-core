import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shown while the app is still booting (loading plugin manifest, restoring the
/// session) and while the backend may be cold-starting. Displays an app icon
/// placeholder and a rolling spinner. The icon falls back to an SF Symbol when
/// no `SplashIcon` asset is bundled — drop a PNG/PDF into
/// `VBWD/Assets.xcassets/SplashIcon.imageset/` to replace it.
@MainActor
public struct SplashView: View {
    @Environment(\.appTheme) private var theme
    private let message: String

    public init(message: String = "Waking up\u{2026}") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                iconView
                    .frame(width: 96, height: 96)
                    .accessibilityIdentifier("splash_icon")

                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(theme.accent)
                    .accessibilityIdentifier("splash_spinner")

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityIdentifier("splash_message")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splash_view")
    }

    @ViewBuilder
    private var iconView: some View {
        if hasBundledSplashIcon {
            Image("SplashIcon")
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.accent)
        }
    }

    private var hasBundledSplashIcon: Bool {
        #if canImport(UIKit)
        return UIImage(named: "SplashIcon") != nil
        #elseif canImport(AppKit)
        return NSImage(named: "SplashIcon") != nil
        #else
        return false
        #endif
    }
}
