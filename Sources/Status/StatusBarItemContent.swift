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
        static let rowSpacing: CGFloat = -1
        static let networkLeadingInset: CGFloat = 5
        static let arrowWidth: CGFloat = 14
        static let arrowTextSpacing: CGFloat = 3
        static let primaryFontSize: CGFloat = 9.5
        static let secondaryFontSize: CGFloat = 7.5
        static let networkFontSize: CGFloat = 8.5
        static let arrowFontSize: CGFloat = 7.5
        // 紧凑模式尺寸
        static let compactPrimaryFontSize: CGFloat = 8.0
        static let compactSecondaryFontSize: CGFloat = 6.5
        static let compactNetworkFontSize: CGFloat = 7.0
        static let compactPercentWidth: CGFloat = 26
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
        let fontSize = s.compactMode ? Layout.compactNetworkFontSize : Layout.networkFontSize
        let arrowFontSize = s.compactMode ? Layout.arrowFontSize * 0.85 : Layout.arrowFontSize

        return HStack(alignment: .firstTextBaseline, spacing: Layout.arrowTextSpacing) {
            // 显示方向箭头（根据设置）
            if s.showNetworkArrows {
                Text(symbol)
                    .font(.system(size: arrowFontSize, weight: .regular))
                    .frame(width: Layout.arrowWidth, alignment: .center)
            }
            Text(StatusBarByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: fontSize, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.leading, s.showNetworkArrows ? Layout.networkLeadingInset : 0)
    }

    private func percentModule(_ fraction: Double, label: String) -> some View {
        let primarySize = s.compactMode ? Layout.compactPrimaryFontSize : Layout.primaryFontSize
        let secondarySize = s.compactMode ? Layout.compactSecondaryFontSize : Layout.secondaryFontSize
        let width = s.compactMode ? Layout.compactPercentWidth : Layout.percentWidth

        return VStack(spacing: Layout.rowSpacing) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: primarySize, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Text(label)
                .font(.system(size: secondarySize, weight: .bold))
                .lineLimit(1)
        }
        .frame(width: width)
    }
}
