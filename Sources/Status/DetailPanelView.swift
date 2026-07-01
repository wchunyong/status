import StatusCore
import SwiftUI

/// 下拉浮窗内容（R-018/D4）。由手动定位的 NSPanel 承载，面板本体透明，
/// 内容层负责材质、圆角与边框。复用状态栏设计系统：统一字阶 + SF Symbol + 细进度条。
/// 绑定 MonitorModel 1s 刷新。
struct DetailPanelView: View {
    @ObservedObject var monitor: MonitorModel
    @ObservedObject var settings: SettingsModel
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private var sample: Sample? {
        monitor.sample
    }

    private var s: StatusSettings {
        settings.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            networkCard
            divider
            memoryCard
            divider
            cpuCard
            if sample?.fanStatus.isSupported ?? AppleSiliconSupport.isSupported() {
                divider
                fanCard
            }
            divider
            footer
        }
        .padding(18)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }

    // MARK: 网络

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("网络")
            HStack(spacing: 24) {
                metric(symbol: "arrow.down", label: "下行", bps: sample?.networkRate.bytesPerSecondIn ?? 0)
                Spacer()
                metric(symbol: "arrow.up", label: "上行", bps: sample?.networkRate.bytesPerSecondOut ?? 0)
            }
        }
    }

    private func metric(symbol: String, label: String, bps: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ByteRateFormatter(unit: s.networkUnit).format(bytesPerSecond: bps))
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
                Text(label)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: 内存

    private var memoryCard: some View {
        let mem = sample?.memory
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                header("内存")
                Spacer()
                Text(percent(mem?.usedFraction ?? 0))
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
            }
            progressBar(mem?.usedFraction ?? 0)
            HStack(spacing: 14) {
                chip("App", mem?.appMemoryBytes ?? 0)
                chip("Wired", mem?.wiredBytes ?? 0)
                chip("压缩", mem?.compressedBytes ?? 0)
                Spacer()
            }
        }
    }

    private func chip(_ key: String, _ bytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(ByteFormatter(unit: s.memoryUnit).format(bytes: bytes))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    private func textChip(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    // MARK: CPU

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                header("CPU")
                Spacer()
                Text(percent(sample?.cpuFraction ?? 0))
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
            }
            progressBar(sample?.cpuFraction ?? 0)
        }
    }

    // MARK: 风扇

    private var fanCard: some View {
        let status = sample?.fanStatus ?? .unavailable
        let formatter = FanDisplayFormatter()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                header("风扇")
                Spacer()
                Text(formatter.temperatureString(status.averageTemperatureCelsius))
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
            }
            HStack(spacing: 16) {
                textChip("平均温度", formatter.temperatureString(status.averageTemperatureCelsius))
                textChip("转速", formatter.rpmString(status.fanRPM))
                Spacer()
            }
        }
    }

    // MARK: 复用组件

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func progressBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(Color.accentColor)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 5)
    }

    private var divider: some View {
        Divider().opacity(0.5)
    }

    private var footer: some View {
        HStack {
            Button("设置…") { onOpenSettings() }
            Spacer()
            Button("退出 Status") { onQuit() }
                .foregroundStyle(.red)
        }
        .font(.system(size: 12))
    }
}
