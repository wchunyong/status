import Foundation

/// 网络接口累计字节计数快照（来自 getifaddrs，已聚合物理接口、排除环回）。
public struct NetworkCounters: Sendable, Equatable, Codable {
    public let bytesIn: UInt64
    public let bytesOut: UInt64

    public init(bytesIn: UInt64, bytesOut: UInt64) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

/// 网络速率（字节/秒）。
public struct NetworkRate: Sendable, Equatable, Codable {
    public let bytesPerSecondIn: Double
    public let bytesPerSecondOut: Double

    public init(bytesPerSecondIn: Double, bytesPerSecondOut: Double) {
        self.bytesPerSecondIn = bytesPerSecondIn
        self.bytesPerSecondOut = bytesPerSecondOut
    }
}

/// 网络速率与回绕处理（B2/B4/B5）。纯函数，便于单测。
public enum NetworkMath {
    /// 由两次累计计数与真实间隔计算速率。
    /// - intervalSeconds <= 0 → nil
    /// - 计数回绕（curr < prev，接口重置）→ nil（调用方应丢弃本次差值，B4）
    public static func rate(prev: NetworkCounters, curr: NetworkCounters,
                            intervalSeconds: Double) -> NetworkRate?
    {
        guard intervalSeconds > 0 else { return nil }
        guard curr.bytesIn >= prev.bytesIn, curr.bytesOut >= prev.bytesOut else { return nil }
        let inRate = Double(curr.bytesIn &- prev.bytesIn) / intervalSeconds
        let outRate = Double(curr.bytesOut &- prev.bytesOut) / intervalSeconds
        return NetworkRate(bytesPerSecondIn: inRate, bytesPerSecondOut: outRate)
    }
}
