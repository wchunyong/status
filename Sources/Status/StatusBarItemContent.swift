import StatusCore
import SwiftUI

/// 状态栏项内容（图5 三模块两行样式）。SwiftUI，经 NSHostingView 装入 statusItem.view。
/// 左：网络（↑上传在上 / ↓下载在下）；中：内存（大号% / 小字 MEM）；右：CPU（大号% / 小字 CPU）。
/// 绑定 MonitorModel + SettingsModel，随 1s 采样自动刷新。点击触发 onClick。
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
                ForEach(s.itemOrder.filter { s.isVisible($0) }, id: \.self) { item in
                    block(for: item)
                }
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func block(for item: StatusItem) -> some View {
        switch item {
        case .network:
            VStack(alignment: .leading, spacing: 0) {
                rateRow("↑", sample?.networkRate.bytesPerSecondOut ?? 0)
                rateRow("↓", sample?.networkRate.bytesPerSecondIn ?? 0)
            }
            .frame(width: 74, alignment: .leading)
        case .memory:
            percentBlock(sample?.memory.usedFraction ?? 0, "MEM")
        case .cpu:
            percentBlock(sample?.cpuFraction ?? 0, "CPU")
        }
    }

    private func rateRow(_ arrow: String, _ bps: Double) -> some View {
        HStack(spacing: 3) {
            Text(arrow)
            Text(ByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
        }
        .font(.system(size: 9))
        .monospacedDigit()
    }

    private func percentBlock(_ fraction: Double, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 32)
    }
}
