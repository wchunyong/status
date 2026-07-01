import Foundation

/// 网络速率显示单位。字节单位用 binary（1024），比特单位用 decimal（1000）。
public enum NetworkSpeedUnit: String, CaseIterable, Codable, Sendable {
    case auto // 自动进位 KB/s / MB/s
    case kbps // Kbit/s
    case mbps // Mbit/s
    case kbs // KB/s
    case mbs // MB/s
}

public enum MemoryUnit: String, CaseIterable, Codable, Sendable {
    case autoGB // 自动 GB / MB
    case gb
    case mb
}

public enum MemoryFormat: String, CaseIterable, Codable, Sendable {
    case usedOnly // 12.4 GB
    case usedOfTotal // 12.4 / 24.0 GB
    case percent // 52%
}

public enum CPUFormat: String, CaseIterable, Codable, Sendable {
    case totalPercent // 38%
}

public enum FanControlMode: String, CaseIterable, Codable, Sendable {
    case system
    case fixedRPM
}

public enum AppearanceMode: String, CaseIterable, Codable, Sendable {
    case system, light, dark
}

public enum StatusItem: String, CaseIterable, Codable, Sendable {
    case network, memory, cpu, fan
}

/// 全部可配置项（对应 PRD §5.2 设置五 Tab）。Codable + 字段级默认值，
/// 支持旧版本 JSON 缺字段时回退默认（前向兼容）。
public struct StatusSettings: Codable, Equatable, Sendable {
    public var refreshIntervalSeconds: Double = 1.0
    public var networkUnit: NetworkSpeedUnit = .auto
    public var showNetworkArrows: Bool = true
    public var memoryUnit: MemoryUnit = .autoGB
    public var memoryFormat: MemoryFormat = .usedOfTotal
    public var cpuFormat: CPUFormat = .totalPercent
    public var showCPUPerCore: Bool = false
    public var fanControlMode: FanControlMode = .system
    public var fanFixedRPM: Int = 1400
    public var itemOrder: [StatusItem] = [.network, .memory, .cpu, .fan]
    public var hiddenItems: Set<StatusItem> = []
    public var compactMode: Bool = false
    public var launchAtLogin: Bool = false
    public var appearance: AppearanceMode = .system

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case refreshIntervalSeconds, networkUnit, showNetworkArrows
        case memoryUnit, memoryFormat, cpuFormat, showCPUPerCore
        case fanControlMode, fanFixedRPM
        case itemOrder, hiddenItems, compactMode, launchAtLogin, appearance
    }

    public init(from decoder: Decoder) throws {
        self = StatusSettings() // 先取全部默认值
        let c = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalSeconds = try c.decodeIfPresent(Double.self, forKey: .refreshIntervalSeconds) ?? refreshIntervalSeconds
        networkUnit = try c.decodeIfPresent(NetworkSpeedUnit.self, forKey: .networkUnit) ?? networkUnit
        showNetworkArrows = try c.decodeIfPresent(Bool.self, forKey: .showNetworkArrows) ?? showNetworkArrows
        memoryUnit = try c.decodeIfPresent(MemoryUnit.self, forKey: .memoryUnit) ?? memoryUnit
        memoryFormat = try c.decodeIfPresent(MemoryFormat.self, forKey: .memoryFormat) ?? memoryFormat
        cpuFormat = try c.decodeIfPresent(CPUFormat.self, forKey: .cpuFormat) ?? cpuFormat
        showCPUPerCore = try c.decodeIfPresent(Bool.self, forKey: .showCPUPerCore) ?? showCPUPerCore
        fanControlMode = try c.decodeIfPresent(FanControlMode.self, forKey: .fanControlMode) ?? fanControlMode
        fanFixedRPM = try FanRPMPolicy.clamp(c.decodeIfPresent(Int.self, forKey: .fanFixedRPM) ?? fanFixedRPM)
        itemOrder = try c.decodeIfPresent([StatusItem].self, forKey: .itemOrder) ?? itemOrder
        itemOrder = Self.normalizedItemOrder(itemOrder)
        hiddenItems = try c.decodeIfPresent(Set<StatusItem>.self, forKey: .hiddenItems) ?? hiddenItems
        compactMode = try c.decodeIfPresent(Bool.self, forKey: .compactMode) ?? compactMode
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? appearance
    }

    /// 某项是否在状态栏显示。
    public func isVisible(_ item: StatusItem) -> Bool {
        !hiddenItems.contains(item)
    }

    private static func normalizedItemOrder(_ decoded: [StatusItem]) -> [StatusItem] {
        var result: [StatusItem] = []
        for item in decoded where !result.contains(item) {
            result.append(item)
        }
        for item in StatusSettings().itemOrder where !result.contains(item) {
            result.append(item)
        }
        return result
    }
}

/// 设置持久化（UserDefaults JSON blob）。UserDefaults 自身线程安全，故 @unchecked Sendable。
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "status.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> StatusSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(StatusSettings.self, from: data)
        else {
            return StatusSettings()
        }
        return decoded
    }

    public func save(_ settings: StatusSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
