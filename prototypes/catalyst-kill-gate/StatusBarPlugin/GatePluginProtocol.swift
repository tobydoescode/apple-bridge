import Foundation

// DUPLICATE of GateSpike/GatePluginProtocol.swift — keep in sync.
// See the comment there for why this is copied rather than shared.
@objc(GSStatusBarPluginProtocol)
protocol GatePluginProtocol: NSObjectProtocol {
    func showStatusItem(title: String) -> Bool
    /// MEASURED: NSApplication.terminate is unreliable from a Catalyst process —
    /// the first call surfaces the host window instead of exiting. The app supplies
    /// its own quit action instead.
    func setQuitHandler(_ handler: @escaping @convention(block) () -> Void)

    func updateTitle(_ title: String)
    func activationPolicyDescription() -> String
    func appKitWindowCount() -> Int
}
