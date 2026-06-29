import Foundation

/// 内存页统计快照（来自 Mach host_statistics64 + sysctl hw.memsize）。
/// *Pages 字段为页数，*Bytes 字段为字节。
///
/// B2 口径：已用 = totalBytes − (free + inactive) × pageSize
/// （inactive 视为可回收缓存，与活动监视器「可用」对齐）。
public struct MemoryStats: Sendable, Equatable, Codable {
    public let pageSize: UInt64
    public let freePages: UInt64
    public let activePages: UInt64
    public let inactivePages: UInt64
    public let wiredPages: UInt64
    public let compressedPages: UInt64
    public let totalBytes: UInt64

    public init(pageSize: UInt64, freePages: UInt64, activePages: UInt64,
                inactivePages: UInt64, wiredPages: UInt64, compressedPages: UInt64,
                totalBytes: UInt64)
    {
        self.pageSize = pageSize
        self.freePages = freePages
        self.activePages = activePages
        self.inactivePages = inactivePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
        self.totalBytes = totalBytes
    }

    public var freeBytes: UInt64 {
        freePages &* pageSize
    }

    public var activeBytes: UInt64 {
        activePages &* pageSize
    }

    public var inactiveBytes: UInt64 {
        inactivePages &* pageSize
    }

    public var wiredBytes: UInt64 {
        wiredPages &* pageSize
    }

    public var compressedBytes: UInt64 {
        compressedPages &* pageSize
    }

    /// 可回收字节（free + inactive，对应活动监视器的「可用」）。
    public var reclaimableBytes: UInt64 {
        (freePages &+ inactivePages) &* pageSize
    }

    /// B2 已用字节 = 总量 − 可回收。
    public var usedBytes: UInt64 {
        totalBytes >= reclaimableBytes ? totalBytes &- reclaimableBytes : 0
    }

    /// 已用占比 0...1。
    public var usedFraction: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
    }

    /// 全零占位（读取失败时使用）。
    public static let zero = MemoryStats(pageSize: 0, freePages: 0, activePages: 0,
                                         inactivePages: 0, wiredPages: 0,
                                         compressedPages: 0, totalBytes: 0)
}
