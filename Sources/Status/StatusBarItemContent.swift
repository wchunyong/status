import StatusCore
import SwiftUI

/// 状态栏项内容（图5 三模块两行样式，设计系统 v5）。
///
/// 用户偏好：小、方体（默认 SF Pro）、无彩色、保留文字标签。
/// 字阶：% 9pt semibold / 网络速率 9pt medium / 标签 7pt。全单色，等宽 tabular 防抖。
/// 每个模块固定宽度（避免网络速率变宽时把右侧 CPU 顶出截断）。
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
            HStack(alignment: .center, spacing: 10) {
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
            .frame(width: 70, alignment: .leading)
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
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(width: 30)
    }
}
