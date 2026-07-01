import Foundation
#if canImport(Darwin)
    import Darwin
#endif
#if canImport(IOKit)
    import IOKit
#endif

public struct FanStatus: Sendable, Equatable, Codable {
    public let averageTemperatureCelsius: Double?
    public let fanRPM: Int?
    public let isSupported: Bool
    public let unavailableReason: String?

    public init(averageTemperatureCelsius: Double?, fanRPM: Int?,
                isSupported: Bool, unavailableReason: String?)
    {
        self.averageTemperatureCelsius = averageTemperatureCelsius
        self.fanRPM = fanRPM
        self.isSupported = isSupported
        self.unavailableReason = unavailableReason
    }

    public static func unsupported(_ reason: String) -> FanStatus {
        FanStatus(averageTemperatureCelsius: nil, fanRPM: nil, isSupported: false, unavailableReason: reason)
    }

    public static let unavailable = FanStatus(
        averageTemperatureCelsius: nil,
        fanRPM: nil,
        isSupported: true,
        unavailableReason: nil
    )
}

public enum AppleSiliconSupport {
    public static func isSupported(machine: String? = nil) -> Bool {
        let machine = machine ?? currentMachine()
        return machine == "arm64" || machine == "arm64e"
    }

    private static func currentMachine() -> String {
        #if canImport(Darwin)
            var uts = utsname()
            uname(&uts)
            return withUnsafePointer(to: &uts.machine) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 1) { cString in
                    String(cString: cString)
                }
            }
        #else
            return ""
        #endif
    }
}

public enum FanRPMPolicy {
    public static let minimum = 1200
    public static let maximum = 6500

    public static func clamp(_ rpm: Int) -> Int {
        min(maximum, max(minimum, rpm))
    }
}

public protocol FanDriver: Sendable {
    func readStatus() -> FanStatus
    func setFixedRPM(_ rpm: Int) -> Bool
    func restoreAutomatic() -> Bool
}

public final class FanController: @unchecked Sendable {
    private let driver: FanDriver
    private var appliedMode: FanControlMode = .system
    private var appliedRPM: Int?

    public init(driver: FanDriver) {
        self.driver = driver
    }

    public func sample(settings: StatusSettings) -> FanStatus {
        let status = driver.readStatus()
        guard status.isSupported else { return status }

        switch settings.fanControlMode {
        case .system:
            if appliedMode != .system {
                _ = driver.restoreAutomatic()
                appliedMode = .system
                appliedRPM = nil
            }
        case .fixedRPM:
            let rpm = FanRPMPolicy.clamp(settings.fanFixedRPM)
            if appliedMode != .fixedRPM || appliedRPM != rpm {
                if driver.setFixedRPM(rpm) {
                    appliedMode = .fixedRPM
                    appliedRPM = rpm
                }
            }
        }

        return driver.readStatus()
    }

    public func restoreAutomatic() {
        _ = driver.restoreAutomatic()
        appliedMode = .system
        appliedRPM = nil
    }
}

#if canImport(IOKit)
    public final class SMCFanDriver: FanDriver, @unchecked Sendable {
        private enum Command: UInt8 {
            case readBytes = 5
            case writeBytes = 6
            case readKeyInfo = 9
        }

        private static let selector = UInt32(2)
        private static let unsupportedIntel = "风扇功能仅支持 Apple Silicon Mac"
        private static let unavailable = "无法访问 AppleSMC"

        private let connection: io_connect_t

        public static func makeDefault() -> FanDriver {
            guard AppleSiliconSupport.isSupported() else {
                return UnsupportedFanDriver(reason: unsupportedIntel)
            }
            return SMCFanDriver() ?? UnsupportedFanDriver(reason: unavailable)
        }

        private init?() {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
            guard service != 0 else { return nil }
            defer { IOObjectRelease(service) }

            var connection = io_connect_t()
            guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
                return nil
            }
            self.connection = connection
        }

        deinit {
            IOServiceClose(connection)
        }

        public func readStatus() -> FanStatus {
            FanStatus(
                averageTemperatureCelsius: averageTemperature(),
                fanRPM: readFanRPM(),
                isSupported: true,
                unavailableReason: nil
            )
        }

        public func setFixedRPM(_ rpm: Int) -> Bool {
            let clamped = FanRPMPolicy.clamp(rpm)
            return writeFPE2(key: "F0Tg", value: Double(clamped))
                && writeUInt16(key: "FS! ", value: 1)
        }

        public func restoreAutomatic() -> Bool {
            writeUInt16(key: "FS! ", value: 0)
        }

        private func averageTemperature() -> Double? {
            let cpuValues = readTemperatureValues(keys: ["TC0P", "TC0E", "TC0F", "TC0D", "Tp09", "Tp0T"])
            let gpuValues = readTemperatureValues(keys: ["TG0P", "TG0D", "TG0H", "Tg05", "Tg0D"])
            let grouped = [average(cpuValues), average(gpuValues)].compactMap { $0 }
            return average(grouped)
        }

        private func readTemperatureValues(keys: [String]) -> [Double] {
            keys.compactMap { readTemperature(key: $0) }
        }

        private func average(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        private func readTemperature(key: String) -> Double? {
            guard let bytes = readKey(key), bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        }

        private func readFanRPM() -> Int? {
            guard let bytes = readKey("F0Ac"), bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Int((Double(raw) / 4.0).rounded())
        }

        private func readKey(_ key: String) -> [UInt8]? {
            guard let info = readKeyInfo(key) else { return nil }
            var input = SMCParamStruct()
            var output = SMCParamStruct()
            input.key = Self.fourCharCode(key)
            input.keyInfo = info
            input.data8 = Command.readBytes.rawValue
            guard call(input: &input, output: &output) else { return nil }
            return Self.bytes(from: output.bytes, count: Int(info.dataSize))
        }

        private func readKeyInfo(_ key: String) -> SMCKeyInfoData? {
            var input = SMCParamStruct()
            var output = SMCParamStruct()
            input.key = Self.fourCharCode(key)
            input.data8 = Command.readKeyInfo.rawValue
            guard call(input: &input, output: &output), output.keyInfo.dataSize > 0 else { return nil }
            return output.keyInfo
        }

        private func writeFPE2(key: String, value: Double) -> Bool {
            let raw = UInt16(max(0, min(65535, Int((value * 4.0).rounded()))))
            return writeKey(key, bytes: [UInt8(raw >> 8), UInt8(raw & 0xFF)])
        }

        private func writeUInt16(key: String, value: UInt16) -> Bool {
            writeKey(key, bytes: [UInt8(value >> 8), UInt8(value & 0xFF)])
        }

        private func writeKey(_ key: String, bytes: [UInt8]) -> Bool {
            guard var info = readKeyInfo(key) else { return false }
            info.dataSize = UInt32(bytes.count)

            var input = SMCParamStruct()
            var output = SMCParamStruct()
            input.key = Self.fourCharCode(key)
            input.keyInfo = info
            input.data8 = Command.writeBytes.rawValue
            Self.copy(bytes: bytes, to: &input.bytes)
            return call(input: &input, output: &output)
        }

        private func call(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
            let inputSize = MemoryLayout<SMCParamStruct>.stride
            var outputSize = MemoryLayout<SMCParamStruct>.stride
            let result = IOConnectCallStructMethod(
                connection,
                Self.selector,
                &input,
                inputSize,
                &output,
                &outputSize
            )
            return result == KERN_SUCCESS && output.result == 0
        }

        private static func fourCharCode(_ key: String) -> UInt32 {
            var result: UInt32 = 0
            for scalar in key.utf8.prefix(4) {
                result = (result << 8) | UInt32(scalar)
            }
            return result
        }

        private static func bytes(from bytes: SMCBytes, count: Int) -> [UInt8] {
            withUnsafeBytes(of: bytes) { raw in
                Array(raw.prefix(max(0, min(count, 32))))
            }
        }

        private static func copy(bytes: [UInt8], to target: inout SMCBytes) {
            withUnsafeMutableBytes(of: &target) { raw in
                for (index, byte) in bytes.prefix(32).enumerated() {
                    raw[index] = byte
                }
            }
        }
    }
#else
    public enum SMCFanDriver {
        public static func makeDefault() -> FanDriver {
            UnsupportedFanDriver(reason: "风扇功能仅支持 macOS")
        }
    }
#endif

public struct UnsupportedFanDriver: FanDriver {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public func readStatus() -> FanStatus {
        .unsupported(reason)
    }

    public func setFixedRPM(_: Int) -> Bool {
        false
    }

    public func restoreAutomatic() -> Bool {
        false
    }
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCBytes {
    var b0: UInt8 = 0
    var b1: UInt8 = 0
    var b2: UInt8 = 0
    var b3: UInt8 = 0
    var b4: UInt8 = 0
    var b5: UInt8 = 0
    var b6: UInt8 = 0
    var b7: UInt8 = 0
    var b8: UInt8 = 0
    var b9: UInt8 = 0
    var b10: UInt8 = 0
    var b11: UInt8 = 0
    var b12: UInt8 = 0
    var b13: UInt8 = 0
    var b14: UInt8 = 0
    var b15: UInt8 = 0
    var b16: UInt8 = 0
    var b17: UInt8 = 0
    var b18: UInt8 = 0
    var b19: UInt8 = 0
    var b20: UInt8 = 0
    var b21: UInt8 = 0
    var b22: UInt8 = 0
    var b23: UInt8 = 0
    var b24: UInt8 = 0
    var b25: UInt8 = 0
    var b26: UInt8 = 0
    var b27: UInt8 = 0
    var b28: UInt8 = 0
    var b29: UInt8 = 0
    var b30: UInt8 = 0
    var b31: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = SMCBytes()
}
