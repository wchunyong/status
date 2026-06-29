import AppKit
import StatusCore

/// 管理状态栏项 + 下拉菜单。@MainActor（B8）。
/// 状态栏用 `attributedTitle` 渲染文本（最轻量，R-014）；菜单用自定义 `MenuSectionView`（R-018）。
@MainActor
final class StatusBarManager: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let settingsModel: SettingsModel
    private var latestSample: Sample?

    private var networkView: MenuSectionView?
    private var memoryView: MenuSectionView?
    private var cpuView: MenuSectionView?

    init(settingsModel: SettingsModel) {
        self.settingsModel = settingsModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureMenu()
        statusItem.button?.attributedTitle = Self.render("Status") // R-005 占位
    }

    // MARK: Sample 驱动

    func update(with sample: Sample) {
        latestSample = sample
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

    // MARK: 菜单

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let net = MenuSectionView(title: "网络")
        let mem = MenuSectionView(title: "内存")
        let cpu = MenuSectionView(title: "CPU")
        networkView = net
        memoryView = mem
        cpuView = cpu

        for view in [net, mem, cpu] {
            let item = NSMenuItem()
            item.view = view
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "退出 Status", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        onQuit?()
    }
}

extension StatusBarManager: NSMenuDelegate {
    func menuWillOpen(_: NSMenu) {
        guard let sample = latestSample else { return }
        let s = settingsModel.value
        let rate = ByteRateFormatter(unit: s.networkUnit)
        let down = rate.format(bytesPerSecond: sample.networkRate.bytesPerSecondIn)
        let up = rate.format(bytesPerSecond: sample.networkRate.bytesPerSecondOut)
        networkView?.setValue("↓ \(down)     ↑ \(up)")
        memoryView?.setValue(MemoryDisplayFormatter(format: .usedOfTotal, unit: s.memoryUnit).string(for: sample.memory))
        cpuView?.setValue("\(PercentFormatter().format(fraction: sample.cpuFraction))")
    }
}
