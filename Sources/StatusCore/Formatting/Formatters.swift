import Foundation

// MARK: - 字节量（内存）

/// 字节量格式化。字节单位 binary（1024）。
public struct ByteFormatter: Sendable {
    public let unit: MemoryUnit
    public init(unit: MemoryUnit = .autoGB) {
        self.unit = unit
    }

    private static let mb = 1024.0 * 1024.0
    private static let gb = 1024.0 * 1024.0 * 1024.0

    /// 拆成 (value, unit)，便于 usedOfTotal 这种「值 / 值 单位」组合。
    public func components(bytes: UInt64) -> (value: String, unit: String) {
        let v = Double(bytes)
        switch unit {
        case .autoGB:
            return v >= Self.gb
                ? (String(format: "%.1f", v / Self.gb), "GB")
                : (String(format: "%.0f", v / Self.mb), "MB")
        case .gb:
            return (String(format: "%.1f", v / Self.gb), "GB")
        case .mb:
            return (String(format: "%.0f", v / Self.mb), "MB")
        }
    }

    public func format(bytes: UInt64) -> String {
        let c = components(bytes: bytes)
        return "\(c.value) \(c.unit)"
    }
}

// MARK: - 网络速率

/// 网络速率格式化。字节单位 binary（1024），比特单位 decimal（1000）。
public struct ByteRateFormatter: Sendable {
    public let unit: NetworkSpeedUnit
    public init(unit: NetworkSpeedUnit = .auto) {
        self.unit = unit
    }

    public func format(bytesPerSecond bps: Double) -> String {
        switch unit {
        case .auto:
            return bps >= 1024.0 * 1024.0 ? fixedMB(bps) : fixedKB(bps)
        case .kbs: return fixedKB(bps)
        case .mbs: return fixedMB(bps)
        case .kbps: return "\(Self.trim(bps * 8 / 1000)) Kbps"
        case .mbps: return "\(Self.trim(bps * 8 / 1_000_000)) Mbps"
        }
    }

    private func fixedKB(_ bps: Double) -> String {
        "\(Self.trim(bps / 1024)) KB/s"
    }

    private func fixedMB(_ bps: Double) -> String {
        "\(Self.trim(bps / (1024 * 1024))) MB/s"
    }

    /// 去掉多余尾零：5.50→5.5、2.00→2、0.32→0.32（不变）。
    private static func trim(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        return formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}

// MARK: - 内存显示

/// 内存显示格式化（结合 MemoryFormat + MemoryUnit + MemoryStats）。
public struct MemoryDisplayFormatter: Sendable {
    public let format: MemoryFormat
    public let unit: MemoryUnit
    public init(format: MemoryFormat = .usedOfTotal, unit: MemoryUnit = .autoGB) {
        self.format = format
        self.unit = unit
    }

    public func string(for memory: MemoryStats) -> String {
        let bf = ByteFormatter(unit: unit)
        switch format {
        case .usedOnly:
            return bf.format(bytes: memory.usedBytes)
        case .usedOfTotal:
            let used = bf.components(bytes: memory.usedBytes)
            let total = bf.components(bytes: memory.totalBytes)
            return "\(used.value) / \(total.value) \(total.unit)"
        case .percent:
            return "\(String(format: "%.0f", memory.usedFraction * 100))%"
        }
    }
}

// MARK: - 百分比（CPU）

/// 百分比格式化（CPU 等）。fraction 为 0...1，自动 clamp。
public struct PercentFormatter: Sendable {
    public let decimals: Int
    public init(decimals: Int = 0) {
        self.decimals = decimals
    }

    public func format(fraction: Double) -> String {
        let clamped = max(0, min(1, fraction))
        return String(format: "%.\(decimals)f%%", clamped * 100)
    }
}
