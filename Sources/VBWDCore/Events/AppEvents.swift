/// Event-name catalog. Port of the web `AppEvents` constants. Plugins and core
/// emit/subscribe by these names (decoupled — neither imports the other).
public enum AppEvents {
    // Auth
    public static let authLogin = "auth:login"
    public static let authLogout = "auth:logout"
    public static let authTokenRefreshed = "auth:token-refreshed"
    public static let authSessionExpired = "auth:session-expired"
    // User
    public static let userRegistered = "user:registered"
    public static let userUpdated = "user:updated"
    public static let userDeleted = "user:deleted"
    // Subscription
    public static let subscriptionCreated = "subscription:created"
    public static let subscriptionActivated = "subscription:activated"
    public static let subscriptionUpgraded = "subscription:upgraded"
    public static let subscriptionDowngraded = "subscription:downgraded"
    public static let subscriptionCancelled = "subscription:cancelled"
    public static let subscriptionExpired = "subscription:expired"
    // Payment
    public static let paymentInitiated = "payment:initiated"
    public static let paymentSucceeded = "payment:succeeded"
    public static let paymentFailed = "payment:failed"
    public static let paymentRefunded = "payment:refunded"
    // Checkout
    public static let checkoutStarted = "checkout:started"
    public static let checkoutCompleted = "checkout:completed"
    public static let checkoutFailed = "checkout:failed"
    // Plugin lifecycle
    public static let pluginRegistered = "plugin:registered"
    public static let pluginInitialized = "plugin:initialized"
    public static let pluginError = "plugin:error"
    public static let pluginStopped = "plugin:stopped"
    // UI-local (never sent to backend)
    public static let notificationShow = "notification:show"
    public static let notificationHide = "notification:hide"
    public static let modalOpen = "modal:open"
    public static let modalClose = "modal:close"
    public static let loadingStart = "loading:start"
    public static let loadingEnd = "loading:end"
    // WebSocket
    public static let wsConnected = "ws:connected"
    public static let wsDisconnected = "ws:disconnected"
    public static let wsMessage = "ws:message"
    public static let wsError = "ws:error"
    // Meinchat — local-only nudges that drive inbox refresh on push arrival.
    public static let meinChatMessageReceived = "meinchat:message-received"

    /// Local-only events excluded from backend forwarding (web exclusion list).
    public static let localOnly: Set<String> = [
        notificationShow, notificationHide,
        modalOpen, modalClose,
        loadingStart, loadingEnd,
        meinChatMessageReceived,
    ]
}
