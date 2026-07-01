import Foundation

/// 一次采样的不可变快照，用于驱动 UI 显示。Sendable，可跨 actor 传递（B8）。
public struct Sample: Sendable, Equatable, Codable {
    public let cpuFraction: Double // 0...1
    public let memory: MemoryStats
    public let networkRate: NetworkRate
    public let fanStatus: FanStatus

    public init(cpuFraction: Double, memory: MemoryStats, networkRate: NetworkRate,
                fanStatus: FanStatus = .unavailable)
    {
        self.cpuFraction = cpuFraction
        self.memory = memory
        self.networkRate = networkRate
        self.fanStatus = fanStatus
    }

    /// CPU 占用百分比 0...100。
    public var cpuPercent: Double {
        cpuFraction * 100
    }
}
