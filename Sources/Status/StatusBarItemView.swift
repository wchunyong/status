import AppKit
import StatusCore

/// 两行式状态栏项（图4 样式）：顶行网络（↓↑），底行 CPU + 内存。@MainActor（B8）。
/// 自定义 NSView 以实现稳定的两行布局（NSStatusBarButton 无法可靠多行）。
@MainActor
final class StatusBarItemView: NSView {
    var onClick: (() -> Void)?

    private let topField = NSTextField(labelWithString: "Status")
    private let bottomField = NSTextField(labelWithString: "")
    private weak var settingsModel: SettingsModel?
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
    private let lineHeight: CGFloat = 10
    private let height: CGFloat = 22

    init(settingsModel: SettingsModel) {
        self.settingsModel = settingsModel
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: height))
        wantsLayer = true
        for field in [topField, bottomField] {
            field.isBezeled = false
            field.drawsBackground = false
            field.isEditable = false
            field.isSelectable = false
            field.textColor = NSColor.labelColor
            field.alignment = .center
            field.font = font
            field.cell?.truncatesLastVisibleLine = true
            addSubview(field)
        }
        relayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(sample: Sample) {
        let settings = settingsModel?.value ?? StatusSettings()
        let (top, bottom) = Self.lines(for: sample, settings: settings)
        topField.stringValue = top
        bottomField.stringValue = bottom
        relayout()
    }

    /// 顶行：网络上下行；底行：CPU% + 内存已用。
    private static func lines(for sample: Sample, settings s: StatusSettings) -> (String, String) {
        let net = ByteRateFormatter(unit: s.networkUnit)
        let down = net.format(bytesPerSecond: sample.networkRate.bytesPerSecondIn)
        let up = net.format(bytesPerSecond: sample.networkRate.bytesPerSecondOut)
        let top = s.showNetworkArrows ? "↓\(down) ↑\(up)" : "\(down) \(up)"
        let cpu = PercentFormatter().format(fraction: sample.cpuFraction)
        let mem = ByteFormatter(unit: s.memoryUnit).format(bytes: sample.memory.usedBytes)
        return (top, "\(cpu)   \(mem)")
    }

    private func relayout() {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let topWidth = (topField.stringValue as NSString).size(withAttributes: attrs).width
        let bottomWidth = (bottomField.stringValue as NSString).size(withAttributes: attrs).width
        let width = ceil(max(topWidth, bottomWidth)) + 18
        setFrameSize(NSSize(width: width, height: height))
        let textWidth = width - 18
        topField.frame = NSRect(x: 9, y: height - lineHeight - 1, width: textWidth, height: lineHeight)
        bottomField.frame = NSRect(x: 9, y: 1, width: textWidth, height: lineHeight)
    }

    override func mouseDown(with _: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with _: NSEvent) {
        onClick?()
    }
}
