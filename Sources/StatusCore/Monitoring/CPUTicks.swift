import Foundation

/// 单核 CPU tick 快照（来自 Mach PROCESSOR_CPU_LOAD_INFO）。
/// 所有字段为累计 tick 数，单调递增（除非系统/核心被重置）。
public struct CPUTicks: Sendable, Equatable, Codable {
    public let user: UInt64
    public let system: UInt64
    public let nice: UInt64
    public let idle: UInt64

    public init(user: UInt64, system: UInt64, nice: UInt64, idle: UInt64) {
        self.user = user
        self.system = system
        self.nice = nice
        self.idle = idle
    }

    /// busy = user + system + nice（非 idle 部分）
    public var busy: UInt64 {
        user &+ system &+ nice
    }

    /// total = busy + idle
    public var total: UInt64 {
        busy &+ idle
    }
}

/// CPU 占用率计算（B2 口径）。纯函数、无副作用，便于单测。
public enum CPUUsage {
    /// 给定两次采样的逐核 tick 快照，返回总体占用比例 0...1。
    /// - 核心数不一致或为空 → 0
    /// - totalDelta 为 0（采样间隔内无 tick 推进）→ 0
    /// - 单核计数回退（curr < prev，核心被重置）→ 该核 delta 记 0，不溢出（B1 防御）
    public static func fraction(prev: [CPUTicks], curr: [CPUTicks]) -> Double {
        guard prev.count == curr.count, !curr.isEmpty else { return 0 }
        var busyDelta: UInt64 = 0
        var totalDelta: UInt64 = 0
        for (p, c) in zip(prev, curr) {
            busyDelta &+= c.busy >= p.busy ? c.busy &- p.busy : 0
            totalDelta &+= c.total >= p.total ? c.total &- p.total : 0
        }
        guard totalDelta > 0 else { return 0 }
        if busyDelta > totalDelta { busyDelta = totalDelta }
        return Double(busyDelta) / Double(totalDelta)
    }

    /// 占用百分比 0...100。
    public static func percent(prev: [CPUTicks], curr: [CPUTicks]) -> Double {
        fraction(prev: prev, curr: curr) * 100
    }
}
