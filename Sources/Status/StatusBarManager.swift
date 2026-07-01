import AppKit
import StatusCore
import SwiftUI

/// 管理状态栏项（三模块两行）+ 下拉浮窗。@MainActor（B8）。
/// 状态栏：`StatusBarItemView`（NSHostingView 装 SwiftUI 内容，图5 样式，R-014 修订）。
/// 浮窗：手动定位的 `NSPanel` + SwiftUI 详情（R-018，D4）。两者都绑定 MonitorModel，随 1s 采样自动刷新。
@MainActor
final class StatusBarManager: NSObject {
    private enum Layout {
        static let panelWidth: CGFloat = 316
        static let fallbackPanelHeight: CGFloat = 392
        static let screenPadding: CGFloat = 8
        static let menuBarGap: CGFloat = 6
    }

    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var shouldShowPopover: (() -> Bool)?

    private let statusItem: NSStatusItem
    private let statusBarView: StatusBarItemView
    private let settingsModel: SettingsModel
    private let monitorModel: MonitorModel
    private var detailPanel: NSPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    init(settingsModel: SettingsModel, monitorModel: MonitorModel) {
        self.settingsModel = settingsModel
        self.monitorModel = monitorModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarView = StatusBarItemView(monitor: monitorModel, settings: settingsModel)
        super.init()

        statusBarView.setOnClick { [weak self] in self?.togglePopover() }
        // NSStatusItem.view 已弃用（10.14+），但自定义多行布局仍需它；macOS 14/26 可用。
        statusItem.view = statusBarView
    }

    // MARK: 浮窗

    private func togglePopover() {
        if detailPanel?.isVisible == true {
            closePopover()
            return
        }
        guard shouldShowPopover?() ?? true else {
            return
        }
        let panel = DetailPanelView(
            monitor: monitorModel,
            settings: settingsModel,
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.onOpenSettings?()
            },
            onQuit: { [weak self] in self?.onQuit?() }
        )
        let hosting = NSHostingController(rootView: panel)
        let size = panelSize(for: hosting)
        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.setFrame(panelFrame(size: size), display: true)
        detailPanel = window
        installDismissMonitors()
        window.orderFrontRegardless()
    }

    func closePopover() {
        detailPanel?.orderOut(nil)
        detailPanel = nil
        removeDismissMonitors()
    }

    private func panelFrame(size: NSSize) -> NSRect {
        let screen = statusBarView.window?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let statusFrame = statusBarView.window?.convertToScreen(
            statusBarView.convert(statusBarView.bounds, to: nil)
        )
        let preferredMidX = statusFrame?.midX ?? visibleFrame.midX
        let x = min(
            max(preferredMidX - size.width / 2, visibleFrame.minX + Layout.screenPadding),
            visibleFrame.maxX - size.width - Layout.screenPadding
        )
        return NSRect(
            x: x,
            y: visibleFrame.maxY - size.height - Layout.menuBarGap,
            width: size.width,
            height: size.height
        )
    }

    private func panelSize(for hosting: NSHostingController<DetailPanelView>) -> NSSize {
        hosting.view.layoutSubtreeIfNeeded()
        let measured = hosting.sizeThatFits(in: NSSize(width: Layout.panelWidth, height: CGFloat.greatestFiniteMagnitude))
        let height = measured.height.isFinite && measured.height > 100
            ? measured.height
            : Layout.fallbackPanelHeight
        return NSSize(width: Layout.panelWidth, height: ceil(height))
    }

    private func installDismissMonitors() {
        removeDismissMonitors()
        let localMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: localMask) { [weak self] event in
            if event.window !== self?.detailPanel {
                self?.closePopover()
            }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
    }

    private func removeDismissMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }
}
