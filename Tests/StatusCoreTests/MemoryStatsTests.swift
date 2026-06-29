@testable import StatusCore
import XCTest

final class MemoryStatsTests: XCTestCase {
    private let pageSize: UInt64 = 4096
    private let gb: UInt64 = 1024 * 1024 * 1024

    func testUsedBytesFormula() {
        // total 24GB；free 1_000_000 页、inactive 500_000 页
        let total = 24 * gb
        let freePages: UInt64 = 1_000_000
        let inactivePages: UInt64 = 500_000
        let reclaimable = (freePages + inactivePages) * pageSize
        let expectedUsed = total - reclaimable

        let stats = MemoryStats(pageSize: pageSize, freePages: freePages, activePages: 600_000,
                                inactivePages: inactivePages, wiredPages: 300_000,
                                compressedPages: 200_000, totalBytes: total)
        XCTAssertEqual(stats.reclaimableBytes, reclaimable)
        XCTAssertEqual(stats.usedBytes, expectedUsed)
        XCTAssertLessThan(stats.usedFraction, 1.0)
        XCTAssertGreaterThan(stats.usedFraction, 0)
    }

    func testByteDerivedProperties() {
        let stats = MemoryStats(pageSize: 4096, freePages: 1, activePages: 2,
                                inactivePages: 3, wiredPages: 4, compressedPages: 5,
                                totalBytes: 0)
        XCTAssertEqual(stats.freeBytes, 4096)
        XCTAssertEqual(stats.activeBytes, 8192)
        XCTAssertEqual(stats.inactiveBytes, 12288)
        XCTAssertEqual(stats.wiredBytes, 16384)
        XCTAssertEqual(stats.compressedBytes, 20480)
    }

    func testUsedClampsToZeroWhenReclaimableExceedsTotal() {
        // 异常：可回收 > 总量 → 已用 clamp 0，不溢出
        let stats = MemoryStats(pageSize: 4096, freePages: 10_000_000, activePages: 0,
                                inactivePages: 10_000_000, wiredPages: 0,
                                compressedPages: 0, totalBytes: 1_000_000)
        XCTAssertEqual(stats.usedBytes, 0)
    }

    func testZeroTotalMeansZeroFraction() {
        let stats = MemoryStats(pageSize: 4096, freePages: 0, activePages: 0,
                                inactivePages: 0, wiredPages: 0, compressedPages: 0,
                                totalBytes: 0)
        XCTAssertEqual(stats.usedFraction, 0)
    }

    func testAllUsedWhenNoFreeOrInactive() {
        let total = 16 * gb
        let stats = MemoryStats(pageSize: 4096, freePages: 0, activePages: 100,
                                inactivePages: 0, wiredPages: 200, compressedPages: 300,
                                totalBytes: total)
        XCTAssertEqual(stats.usedBytes, total)
        XCTAssertEqual(stats.usedFraction, 1.0, accuracy: 1e-9)
    }
}
