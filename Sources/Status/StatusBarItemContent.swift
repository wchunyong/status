import StatusCore
import SwiftUI

/// 状态栏项内容（图5 三模块两行样式，设计系统 v4）。
///
/// 用户偏好：小、方体（默认 SF Pro，非圆体）、无彩色、保留文字标签。
/// 字阶：% 10pt semibold（主角）/ 网络速率 9pt medium（配角）/ 标签 7pt medium 大写+tracking。
/// 全单色（数字 primary，箭头与标签 secondary）。等宽 tabular 防抖。
struct StatusBarItemContent: View {
    @ObservedObject var monitor: MonitorModel
    @ObservedObject var settings: SettingsModel
    let onClick: () -> Void

    private var sample: Sample? {
        monitor.sample
    }

    private var s: StatusSettings {
        settings.value
    }

    var body: some View {
        Button(action: onClick) {
            HStack(alignment: .center, spacing: 12) {
                ForEach(visibleItems, id: \.self) { item in
                    module(for: item)
                }
            }
            .fixedSize()
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
            VStack(alignment: .leading, spacing: 1) {
                rateRow(symbol: "arrow.up", bps: sample?.networkRate.bytesPerSecondOut ?? 0)
                rateRow(symbol: "arrow.down", bps: sample?.networkRate.bytesPerSecondIn ?? 0)
            }
        case .memory:
            percentModule(sample?.memory.usedFraction ?? 0, label: "MEM")
        case .cpu:
            percentModule(sample?.cpuFraction ?? 0, label: "CPU")
        }
    }

    private func rateRow(symbol: String, bps: Double) -> some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(ByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
        }
    }

    private func percentModule(_ fraction: Double, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
    }
}
