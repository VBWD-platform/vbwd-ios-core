# VBWDCore iOS SDK — LLM Agent Documentation

Structured context for LLM coding agents (Claude, GPT, Copilot, Cursor, etc.) to generate correct VBWDCore-based code.

## Documents

| Document | Use When |
|----------|----------|
| [SDK-REFERENCE.md](SDK-REFERENCE.md) | Building apps on top of VBWDCore (host app setup, using SDK types) |
| [PLUGIN-DEVELOPMENT.md](PLUGIN-DEVELOPMENT.md) | Creating plugins that extend VBWDCore apps |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Understanding the SDK's layered design and SOLID patterns |

## Quick Context

- **Module**: `VBWDCore` (Swift Package, Swift 6, strict concurrency)
- **Platforms**: iOS 16+, macOS 13+
- **Architecture**: SOLID + TDD, plugin system, web parity with `vbwd-fe-core`
- **GitHub org**: `VBWD-platform`
- **Host app**: `vbwd-ios` (SwiftUI app using `AppRoot` from VBWDCore)
- **Plugin repos**: `vbwd-ios-plugin-{name}`
