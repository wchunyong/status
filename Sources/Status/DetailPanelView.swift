import StatusCore
import SwiftUI

/// 下拉浮窗内容（R-018 修订：浮窗而非菜单）。绑定 MonitorModel，随 1s 采样自动刷新。
struct DetailPanelView: View {
    @ObservedObject var monitor: MonitorModel
    @ObservedObject var settings: SettingsModel
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private var sample: Sample? {
        monitor.sample
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            networkCard
            Divider()
            memoryCard
            Divider()
            cpuCard
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
        .glassBackground()
    }

    // MARK: 网络

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader("网络")
            HStack(spacing: 20) {
                metric(value: downText, label: "↓ 下行")
                Spacer()
                metric(value: upText, label: "↑ 上行")
            }
        }
    }

    private var downText: String {
        sample.map { ByteRateFormatter(unit: settings.value.networkUnit)
            .format(bytesPerSecond: $0.networkRate.bytesPerSecondIn)
        } ?? "—"
    }

    private var upText: String {
        sample.map { ByteRateFormatter(unit: settings.value.networkUnit)
            .format(bytesPerSecond: $0.networkRate.bytesPerSecondOut)
        } ?? "—"
    }

    // MARK: 内存

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                cardHeader("内存")
                Spacer()
                Text(memoryPercent)
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            }
            progressBar(fraction: sample?.memory.usedFraction ?? 0)
            Text("\(memoryUsed) / \(memoryTotal)")
                .font(.system(.callout, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
            breakdown
        }
    }

    private var memoryPercent: String {
        sample.map { "\(Int(($0.memory.usedFraction * 100).rounded()))%" } ?? "—"
    }

    private var memoryUsed: String {
        sample.map { ByteFormatter(unit: settings.value.memoryUnit).format(bytes: $0.memory.usedBytes) } ?? "—"
    }

    private var memoryTotal: String {
        sample.map { ByteFormatter(unit: settings.value.memoryUnit).format(bytes: $0.memory.totalBytes) } ?? "—"
    }

    @ViewBuilder
    private var breakdown: some View {
        if let mem = sample?.memory {
            HStack(spacing: 10) {
                chip("App", ByteFormatter(unit: settings.value.memoryUnit).format(bytes: mem.activeBytes))
                chip("Wired", ByteFormatter(unit: settings.value.memoryUnit).format(bytes: mem.wiredBytes))
                chip("压缩", ByteFormatter(unit: settings.value.memoryUnit).format(bytes: mem.compressedBytes))
            }
            .font(.caption2)
        }
    }

    // MARK: CPU

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                cardHeader("CPU")
                Spacer()
                Text("\(cpuPercent)")
                    .font(.system(.title3, design: .rounded).monospacedDigit().weight(.bold))
            }
            progressBar(fraction: sample?.cpuFraction ?? 0)
        }
    }

    private var cpuPercent: String {
        sample.map { "\(Int(($0.cpuFraction * 100).rounded()))%" } ?? "—"
    }

    // MARK: 通用组件

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).foregroundStyle(.secondary)
            Text(v).monospacedDigit()
        }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 6)
    }

    private var footer: some View {
        HStack {
            Button("设置…") { onOpenSettings() }
            Spacer()
            Button("退出 Status") { onQuit() }
                .foregroundStyle(.red)
        }
        .font(.callout)
    }
}
