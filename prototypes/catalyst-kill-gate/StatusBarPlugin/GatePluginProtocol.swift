import Foundation

// DUPLICATE of GateSpike/GatePluginProtocol.swift — keep in sync.
// See the comment there for why this is copied rather than shared.
@objc(GSStatusBarPluginProtocol)
protocol GatePluginProtocol: NSObjectProtocol {
    func showStatusItem(title: String) -> Bool
    func updateTitle(_ title: String)
    func activationPolicyDescription() -> String
    func appKitWindowCount() -> Int
}
