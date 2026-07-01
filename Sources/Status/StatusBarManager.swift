import AppKit
import StatusCore
import SwiftUI

/// 管理状态栏项（三模块两行）+ 下拉浮窗。@MainActor（B8）。
/// 状态栏：`StatusBarItemView`（NSHostingView 装 SwiftUI 内容，图5 样式，R-014 修订）。
/// 浮窗：`NSPopover` + SwiftUI 详情（R-018，D4）。两者都绑定 MonitorModel，随 1s 采样自动刷新。
@MainActor
final class StatusBarManager: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var shouldShowPopover: (() -> Bool)?

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let statusBarView: StatusBarItemView
    private let settingsModel: SettingsModel
    private let monitorModel: MonitorModel

    init(settingsModel: SettingsModel, monitorModel: MonitorModel) {
        self.settingsModel = settingsModel
        self.monitorModel = monitorModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        statusBarView = StatusBarItemView(monitor: monitorModel, settings: settingsModel)
        super.init()

        popover.behavior = .transient
        popover.animates = true

        statusBarView.setOnClick { [weak self] in self?.togglePopover() }
        // NSStatusItem.view 已弃用（10.14+），但自定义多行布局仍需它；macOS 14/26 可用。
        statusItem.view = statusBarView
    }

    // MARK: 浮窗

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard shouldShowPopover?() ?? true else {
            return
        }
        let panel = DetailPanelView(
            monitor: monitorModel,
            settings: settingsModel,
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.onOpenSettings?()
            },
            onQuit: { [weak self] in self?.onQuit?() }
        )
        popover.contentViewController = NSHostingController(rootView: panel)
        popover.show(relativeTo: statusBarView.bounds, of: statusBarView, preferredEdge: .maxY)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
