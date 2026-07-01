@testable import StatusCore
import XCTest

final class StatusSettingsTests: XCTestCase {
    func testDefaults() {
        let s = StatusSettings()
        XCTAssertEqual(s.refreshIntervalSeconds, 1.0)
        XCTAssertEqual(s.networkUnit, .auto)
        XCTAssertTrue(s.showNetworkArrows)
        XCTAssertEqual(s.memoryFormat, .usedOfTotal)
        XCTAssertEqual(s.cpuFormat, .totalPercent)
        XCTAssertEqual(s.itemOrder, [.network, .memory, .cpu, .fan])
        XCTAssertEqual(s.fanControlMode, .system)
        XCTAssertEqual(s.fanFixedRPM, 1400)
        XCTAssertTrue(s.hiddenItems.isEmpty)
        XCTAssertTrue(s.isVisible(.cpu))
        XCTAssertTrue(s.isVisible(.fan))
    }

    func testHiddenItemsAffectsVisibility() {
        var s = StatusSettings()
        s.hiddenItems = [.cpu]
        XCTAssertFalse(s.isVisible(.cpu))
        XCTAssertTrue(s.isVisible(.network))
    }

    func testStoreRoundTrip() throws {
        let suite = "test.status.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)

        // 无数据 → 默认
        XCTAssertEqual(store.load().memoryFormat, .usedOfTotal)

        var s = store.load()
        s.networkUnit = .mbs
        s.memoryFormat = .percent
        s.refreshIntervalSeconds = 5
        s.fanControlMode = .fixedRPM
        s.fanFixedRPM = 2400
        s.hiddenItems = [.cpu]
        store.save(s)

        let loaded = store.load()
        XCTAssertEqual(loaded.networkUnit, .mbs)
        XCTAssertEqual(loaded.memoryFormat, .percent)
        XCTAssertEqual(loaded.refreshIntervalSeconds, 5)
        XCTAssertEqual(loaded.fanControlMode, .fixedRPM)
        XCTAssertEqual(loaded.fanFixedRPM, 2400)
        XCTAssertFalse(loaded.isVisible(.cpu))
    }

    func testStoreClear() throws {
        let suite = "test.status.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)

        var s = store.load()
        s.compactMode = true
        store.save(s)
        XCTAssertTrue(store.load().compactMode)

        store.clear()
        XCTAssertFalse(store.load().compactMode)
    }

    func testPartialJSONFallsBackToDefaults() {
        // 仿旧版本 JSON 缺字段：已写字段保留，缺失字段回退默认
        let json = Data("""
        {"refreshIntervalSeconds": 5.0, "showNetworkArrows": false}
        """.utf8)
        let decoded = try? JSONDecoder().decode(StatusSettings.self, from: json)
        XCTAssertEqual(decoded?.refreshIntervalSeconds, 5.0)
        XCTAssertEqual(decoded?.showNetworkArrows, false)
        XCTAssertEqual(decoded?.networkUnit, .auto)
        XCTAssertEqual(decoded?.memoryFormat, .usedOfTotal)
        XCTAssertEqual(decoded?.fanControlMode, .system)
        XCTAssertEqual(decoded?.fanFixedRPM, 1400)
    }

    func testOldItemOrderAppendsNewFanItem() {
        let json = Data("""
        {"itemOrder": ["network", "memory", "cpu"]}
        """.utf8)
        let decoded = try? JSONDecoder().decode(StatusSettings.self, from: json)
        XCTAssertEqual(decoded?.itemOrder, [.network, .memory, .cpu, .fan])
        XCTAssertTrue(decoded?.isVisible(.fan) ?? false)
    }

    func testCorruptDataFallsBackToDefaults() throws {
        let suite = "test.status.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        defaults.set(Data("not json".utf8), forKey: "status.settings.v1")
        XCTAssertEqual(store.load().networkUnit, .auto) // 损坏 → 默认
    }
}
