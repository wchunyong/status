import StatusCore
import SwiftUI

/// 状态栏项内容（图5 三模块两行样式，设计系统 v3）。
///
/// 设计轴：所有数字统一 **SF Rounded + 等宽 tabular**（一致性是好看的基础）。
/// 层次：% 用 12pt bold（主角）/ 网络速率 10pt semibold（配角）。
/// 标签：8pt semibold 大写 + tracking（精致）。箭头 SF Symbol，下载蓝色强调。
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
            HStack(alignment: .center, spacing: 14) {
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
                rateRow(symbol: "arrow.up", tint: .secondary, bps: sample?.networkRate.bytesPerSecondOut ?? 0)
                rateRow(symbol: "arrow.down", tint: .blue, bps: sample?.networkRate.bytesPerSecondIn ?? 0)
            }
        case .memory:
            percentModule(sample?.memory.usedFraction ?? 0, label: "MEM")
        case .cpu:
            percentModule(sample?.cpuFraction ?? 0, label: "CPU")
        }
    }

    private func rateRow(symbol: String, tint: Color, bps: Double) -> some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(tint)
            Text(ByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private func percentModule(_ fraction: Double, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
    }
}
