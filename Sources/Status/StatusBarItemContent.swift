import StatusCore
import SwiftUI

/// 状态栏项内容（三模块两行样式）。
///
/// 用户偏好：小、方体（默认 SF Pro）、无彩色、保留文字标签。
/// 每个模块固定宽度，避免网络速率变宽时把右侧 CPU 顶出截断。
struct StatusBarItemContent: View {
    @ObservedObject var monitor: MonitorModel
    @ObservedObject var settings: SettingsModel
    let onClick: () -> Void

    private enum Layout {
        static let itemSpacing: CGFloat = 10
        static let networkWidth: CGFloat = 65
        static let percentWidth: CGFloat = 30
        static let rowSpacing: CGFloat = 0
        static let networkLeadingInset: CGFloat = 5
        static let arrowWidth: CGFloat = 14
        static let arrowTextSpacing: CGFloat = 3
    }

    private var sample: Sample? {
        monitor.sample
    }

    private var s: StatusSettings {
        settings.value
    }

    var body: some View {
        Button(action: onClick) {
            HStack(alignment: .center, spacing: Layout.itemSpacing) {
                ForEach(visibleItems, id: \.self) { item in
                    module(for: item)
                }
            }
            .fontDesign(.default)
            .foregroundStyle(Color(nsColor: .labelColor))
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var visibleItems: [StatusItem] {
        s.itemOrder.filter { s.isVisible($0) }
    }

    @ViewBuilder
    private func module(for item: StatusItem) -> some View {
        switch item {
        case .network:
            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                rateRow(symbol: "↑", bps: sample?.networkRate.bytesPerSecondOut ?? 0)
                rateRow(symbol: "↓", bps: sample?.networkRate.bytesPerSecondIn ?? 0)
            }
            .frame(width: Layout.networkWidth, alignment: .leading)
        case .memory:
            percentModule(sample?.memory.usedFraction ?? 0, label: "MEM")
        case .cpu:
            percentModule(sample?.cpuFraction ?? 0, label: "CPU")
        }
    }

    private func rateRow(symbol: String, bps: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.arrowTextSpacing) {
            Text(symbol)
                .font(.system(size: 8, weight: .regular))
                .frame(width: Layout.arrowWidth, alignment: .center)
            Text(StatusBarByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.leading, Layout.networkLeadingInset)
    }

    private func percentModule(_ fraction: Double, label: String) -> some View {
        VStack(spacing: Layout.rowSpacing) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .lineLimit(1)
        }
        .frame(width: Layout.percentWidth)
    }
}
