@testable import StatusCore
import XCTest

final class FormatterTests: XCTestCase {
    // MARK: ByteRateFormatter

    func testByteRateAutoMB() {
        let f = ByteRateFormatter(unit: .auto)
        XCTAssertEqual(f.format(bytesPerSecond: 5.5 * 1024 * 1024), "5.5 MB/s")
    }

    func testByteRateAutoKB() {
        let f = ByteRateFormatter(unit: .auto)
        XCTAssertEqual(f.format(bytesPerSecond: 328), "0.32 KB/s") // 328/1024=0.3203
    }

    func testByteRateAutoBoundary() {
        // 恰好 1 MB/s 边界 → 走 MB
        let f = ByteRateFormatter(unit: .auto)
        XCTAssertEqual(f.format(bytesPerSecond: 1024.0 * 1024.0), "1 MB/s")
    }

    func testByteRateFixedKB() {
        XCTAssertEqual(ByteRateFormatter(unit: .kbs).format(bytesPerSecond: 2048), "2 KB/s")
    }

    func testByteRateMbps() {
        XCTAssertEqual(ByteRateFormatter(unit: .mbps).format(bytesPerSecond: 125_000), "1 Mbps")
    }

    func testStatusBarByteRateKeepsThreeColumnValue() {
        let f = StatusBarByteRateFormatter()
        XCTAssertEqual(f.format(bytesPerSecond: 0), "  0 KB/s")
        XCTAssertEqual(f.format(bytesPerSecond: 2 * 1024), "  2 KB/s")
        XCTAssertEqual(f.format(bytesPerSecond: 15 * 1024), " 15 KB/s")
        XCTAssertEqual(f.format(bytesPerSecond: 987 * 1024), "987 KB/s")
    }

    func testStatusBarByteRateAutoPromotesToMB() {
        let f = StatusBarByteRateFormatter()
        XCTAssertEqual(f.format(bytesPerSecond: 1.5 * 1024 * 1024), "1.5 MB/s")
        XCTAssertEqual(f.format(bytesPerSecond: 15 * 1024 * 1024), " 15 MB/s")
        XCTAssertEqual(f.format(bytesPerSecond: 150 * 1024 * 1024), "150 MB/s")
    }

    // MARK: ByteFormatter

    func testByteFormatterAutoGB() {
        XCTAssertEqual(ByteFormatter(unit: .autoGB).format(bytes: 12 * 1024 * 1024 * 1024), "12.0 GB")
    }

    func testByteFormatterAutoMB() {
        XCTAssertEqual(ByteFormatter(unit: .autoGB).format(bytes: 500 * 1024 * 1024), "500 MB")
    }

    func testByteFormatterFixedMB() {
        XCTAssertEqual(ByteFormatter(unit: .mb).format(bytes: 2 * 1024 * 1024), "2 MB")
    }

    // MARK: MemoryDisplayFormatter

    func testMemoryDisplayUsedOfTotal() {
        // total 24GB；可回收 6GB → 已用 18GB
        let total: UInt64 = 24 * 1024 * 1024 * 1024
        let pages: UInt64 = (6 * 1024 * 1024 * 1024) / 4096 // = 1572864 页
        let mem = MemoryStats(pageSize: 4096, freePages: pages / 2, activePages: 0,
                              inactivePages: pages / 2, wiredPages: 0, compressedPages: 0,
                              totalBytes: total)
        let f = MemoryDisplayFormatter(format: .usedOfTotal, unit: .gb)
        XCTAssertEqual(f.string(for: mem), "18.0 / 24.0 GB")
    }

    func testMemoryDisplayPercent() {
        // total 16GB；可回收 8GB → 已用 8GB → 50%
        let total: UInt64 = 16 * 1024 * 1024 * 1024
        let pages: UInt64 = (8 * 1024 * 1024 * 1024) / 4096
        let mem = MemoryStats(pageSize: 4096, freePages: pages, activePages: 0,
                              inactivePages: 0, wiredPages: 0, compressedPages: 0,
                              totalBytes: total)
        XCTAssertEqual(MemoryDisplayFormatter(format: .percent, unit: .gb).string(for: mem), "50%")
    }

    func testMemoryDisplayUsedOnly() {
        let total: UInt64 = 16 * 1024 * 1024 * 1024
        let pages: UInt64 = (8 * 1024 * 1024 * 1024) / 4096
        let mem = MemoryStats(pageSize: 4096, freePages: pages, activePages: 0,
                              inactivePages: 0, wiredPages: 0, compressedPages: 0,
                              totalBytes: total)
        XCTAssertEqual(MemoryDisplayFormatter(format: .usedOnly, unit: .gb).string(for: mem), "8.0 GB")
    }

    // MARK: PercentFormatter

    func testPercentFormatterRounding() {
        let f = PercentFormatter(decimals: 0)
        XCTAssertEqual(f.format(fraction: 0.38), "38%")
        XCTAssertEqual(f.format(fraction: 0.377), "38%") // 37.7 → 38
    }

    func testPercentFormatterDecimals() {
        XCTAssertEqual(PercentFormatter(decimals: 1).format(fraction: 0.377), "37.7%")
    }

    func testPercentFormatterClamps() {
        let f = PercentFormatter()
        XCTAssertEqual(f.format(fraction: 1.5), "100%")
        XCTAssertEqual(f.format(fraction: -0.2), "0%")
    }

    // MARK: FanDisplayFormatter

    func testFanDisplayFormatterFormatsValuesAndPlaceholders() {
        let f = FanDisplayFormatter()
        XCTAssertEqual(f.temperatureString(48.6), "49°C")
        XCTAssertEqual(f.temperatureString(nil), "--°C")
        XCTAssertEqual(f.rpmString(1447), "1447R")
        XCTAssertEqual(f.rpmString(nil), "----R")
    }
}
