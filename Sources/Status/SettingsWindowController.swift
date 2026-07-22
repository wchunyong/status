import AppKit
import SwiftUI

/// 用 NSWindow + NSHostingController 承载 SwiftUI 设置界面（R-016/R-017）。
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?

    private var controller: NSWindowController?

    var isVisible: Bool {
        controller?.window?.isVisible ?? false
    }

    init(settingsModel: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: settingsModel))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Status 设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 500, height: 380))
        window.center()
        super.init()
        window.delegate = self
        controller = NSWindowController(window: window)
    }

    func show() {
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
        NSApp?.activate()
    }

    func windowWillClose(_: Notification) {
        controller = nil
        onClose?()
    }
}
