import StatusCore
import SwiftUI

/// 状态栏项内容（图5 三模块两行样式，设计系统 v2）。
///
/// 字阶：数值 11pt medium / 百分比 12pt semibold 圆体（强调）/ 标签 8pt。
/// 箭头用 SF Symbol（次级色）；模块间极细分隔线给结构感；统一间距。
/// 左：网络（↑上传在上 / ↓下载在下）；中：内存；右：CPU。绑定 MonitorModel 自动刷新。
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
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(visibleItems.enumerated()), id: \.element) { index, item in
                    if index > 0 { Self.divider }
                    module(for: item)
                        .padding(.horizontal, 8)
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
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(ByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private func percentModule(_ fraction: Double, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    private static var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 0.5, height: 15)
    }
}
