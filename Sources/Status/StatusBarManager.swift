import AppKit
import StatusCore
import SwiftUI

/// 管理状态栏项（两行式）+ 下拉浮窗。@MainActor（B8）。
/// 状态栏用自定义 `StatusBarItemView`（图4 两行样式，R-014 修订）；
/// 浮窗用 `NSPopover` + SwiftUI 详情（R-018，D4）。
@MainActor
final class StatusBarManager: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let itemView: StatusBarItemView
    private let settingsModel: SettingsModel
    private let monitorModel: MonitorModel

    init(settingsModel: SettingsModel, monitorModel: MonitorModel) {
        self.settingsModel = settingsModel
        self.monitorModel = monitorModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        itemView = StatusBarItemView(settingsModel: settingsModel)
        super.init()

        popover.behavior = .transient
        popover.animates = true

        // NSStatusItem.view 已弃用（10.14+），但自定义多行布局仍需它；macOS 14/26 可用。
        statusItem.view = itemView
        itemView.onClick = { [weak self] in self?.togglePopover() }
    }

    // MARK: Sample 驱动

    func update(with sample: Sample) {
        itemView.update(sample: sample)
    }

    // MARK: 浮窗

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
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
        popover.show(relativeTo: itemView.bounds, of: itemView, preferredEdge: .minY)
    }
}
