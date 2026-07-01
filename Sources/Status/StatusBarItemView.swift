import AppKit
import StatusCore
import SwiftUI

/// 承载 SwiftUI `StatusBarItemContent` 的 NSView，作为 statusItem.view。
/// 固定尺寸（按 fittingSize），mouseDown 触发点击（状态栏里比 SwiftUI Button 更稳）。@MainActor（B8）。
@MainActor
final class StatusBarItemView: NSView {
    private enum Layout {
        static let horizontalPadding: CGFloat = 4
        static let verticalOpticalOffset: CGFloat = -1
    }

    var onClick: (() -> Void)?
    private let hostingView: NSHostingView<StatusBarItemContent>

    init(monitor: MonitorModel, settings: SettingsModel) {
        hostingView = NSHostingView(rootView: StatusBarItemContent(
            monitor: monitor, settings: settings, onClick: {}
        ))
        super.init(frame: .zero)
        addSubview(hostingView)
        applySizing()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 在 super.init 之后注入真实点击闭包（capture StatusBarManager）。
    func setOnClick(_ closure: @escaping () -> Void) {
        let current = hostingView.rootView
        hostingView.rootView = StatusBarItemContent(
            monitor: current.monitor, settings: current.settings, onClick: closure
        )
        applySizing()
    }

    private func applySizing() {
        let fit = hostingView.fittingSize
        let statusBarHeight = NSStatusBar.system.thickness
        let size = NSSize(width: fit.width + Layout.horizontalPadding, height: max(statusBarHeight, fit.height))
        setFrameSize(size)

        let origin = NSPoint(
            x: 0,
            y: floor((size.height - fit.height) / 2) + Layout.verticalOpticalOffset
        )
        hostingView.frame = NSRect(origin: origin, size: NSSize(width: size.width, height: fit.height))
    }

    override func mouseDown(with _: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with _: NSEvent) {
        onClick?()
    }
}
