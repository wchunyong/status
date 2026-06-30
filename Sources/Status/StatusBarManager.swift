import AppKit
import StatusCore
import SwiftUI

/// 管理状态栏项 + 下拉浮窗。@MainActor（B8）。
/// 状态栏用 `attributedTitle` 渲染（R-014）；浮窗用 `NSPopover` + SwiftUI 详情（R-018 修订，D4）。
@MainActor
final class StatusBarManager: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let settingsModel: SettingsModel
    private let monitorModel: MonitorModel

    init(settingsModel: SettingsModel, monitorModel: MonitorModel) {
        self.settingsModel = settingsModel
        self.monitorModel = monitorModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true

        if let button = statusItem.button {
            button.image = nil
            button.attributedTitle = Self.render("Status")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: Sample 驱动

    func update(with sample: Sample) {
        statusItem.button?.attributedTitle = Self.render(composeStatusText(sample: sample))
    }

    // MARK: 状态栏文本

    private func composeStatusText(sample: Sample) -> String {
        let s = settingsModel.value
        var parts: [String] = []
        for item in s.itemOrder where s.isVisible(item) {
            switch item {
            case .network:
                let f = ByteRateFormatter(unit: s.networkUnit)
                let down = f.format(bytesPerSecond: sample.networkRate.bytesPerSecondIn)
                let up = f.format(bytesPerSecond: sample.networkRate.bytesPerSecondOut)
                parts.append(s.showNetworkArrows ? "↓\(down) ↑\(up)" : "\(down) \(up)")
            case .memory:
                let f = MemoryDisplayFormatter(format: s.memoryFormat, unit: s.memoryUnit)
                parts.append(f.string(for: sample.memory))
            case .cpu:
                parts.append(PercentFormatter().format(fraction: sample.cpuFraction))
            }
        }
        let sep = s.compactMode ? "  " : " · "
        return parts.isEmpty ? "Status" : parts.joined(separator: sep)
    }

    private static func render(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    // MARK: 浮窗

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
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
            onQuit: { [weak self] in
                self?.onQuit?()
            }
        )
        popover.contentViewController = NSHostingController(rootView: panel)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
