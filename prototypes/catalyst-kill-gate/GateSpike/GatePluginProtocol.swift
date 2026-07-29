import Foundation

// The seam between the Catalyst app and the AppKit plugin bundle.
//
// This file is DUPLICATED verbatim in StatusBarPlugin/. That is deliberate for a
// throwaway spike: sharing it properly would mean a third framework target, and
// the thing under test is whether the plugin loads at all, not how the protocol
// is vended.
//
// The explicit @objc(...) name matters. Without it Swift mangles the runtime name
// per module, so the app's protocol and the plugin's protocol would be two
// different ObjC protocols and every `as?` cast would fail.
@objc(GSStatusBarPluginProtocol)
protocol GatePluginProtocol: NSObjectProtocol {
    /// CHECK 4: create an NSStatusItem from inside a Catalyst process.
    func showStatusItem(title: String) -> Bool

    /// MEASURED: NSApplication.terminate is unreliable from a Catalyst process —
    /// the first call surfaces the host window instead of exiting. The app supplies
    /// its own quit action instead.
    func setQuitHandler(_ handler: @escaping @convention(block) () -> Void)

    func updateTitle(_ title: String)

    /// CHECK 1, objectively. Only AppKit can answer this, and only the plugin has
    /// AppKit — so the plugin reports the process's real activation policy.
    /// "accessory" means LSUIElement was honoured: no dock icon.
    func activationPolicyDescription() -> String

    /// CHECK 1, second half: how many AppKit windows the process actually has.
    func appKitWindowCount() -> Int
}
