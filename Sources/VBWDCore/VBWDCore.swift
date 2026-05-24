// VBWDCore — iOS SDK porting the web `vbwd-fe-core` auth contract and
// `vbwd-fe-user` views (login + generic user dashboard).
//
// This file is the package namespace only. All behaviour lives in the
// Networking / Persistence / Domain / Session / UI / Composition layers and is
// introduced test-first, subsprint by subsprint (see docs/dev_log).

/// Namespace for SDK-wide metadata. Intentionally logic-free.
public enum VBWDCore {
    /// Sprint 01 target API contract version (web `fe-core` parity).
    public static let apiContractVersion = "v1"
}
