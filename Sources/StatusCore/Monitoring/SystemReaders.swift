import Foundation
#if canImport(Darwin)
    import Darwin
#endif

// MARK: - CPU

/// 读取实时 CPU 逐核 tick 快照（Mach host_processor_info）。资源安全见 B1。
public enum CPUSnapshotReader {
    public static func read() -> [CPUTicks]? {
        var numCPU: natural_t = 0
        var cpuLoad: UnsafeMutablePointer<integer_t>?
        var count: mach_msg_type_number_t = 0
        let host = mach_host_self()
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numCPU, &cpuLoad, &count)
        guard result == KERN_SUCCESS, let info = cpuLoad, numCPU > 0 else { return nil }
        // B1：Mach 分配的内存必须释放，否则每次采样都泄漏。
        defer {
            let size = vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }

        var ticks: [CPUTicks] = []
        ticks.reserveCapacity(Int(numCPU))
        let stride = Int(CPU_STATE_MAX)
        for core in 0 ..< Int(numCPU) {
            let base = core * stride
            // tick 计数非负；防御性 clamp 到 >=0
            let user = UInt64(max(0, Int(info[base + Int(CPU_STATE_USER)])))
            let system = UInt64(max(0, Int(info[base + Int(CPU_STATE_SYSTEM)])))
            let nice = UInt64(max(0, Int(info[base + Int(CPU_STATE_NICE)])))
            let idle = UInt64(max(0, Int(info[base + Int(CPU_STATE_IDLE)])))
            ticks.append(CPUTicks(user: user, system: system, nice: nice, idle: idle))
        }
        return ticks
    }
}

// MARK: - Memory

/// 读取实时内存页统计（Mach host_statistics64）。totalBytes 取 sysctl hw.memsize。
public enum MemorySnapshotReader {
    public static func read() -> MemoryStats? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryStats(
            pageSize: UInt64(getpagesize()),
            freePages: UInt64(stats.free_count),
            activePages: UInt64(stats.active_count),
            inactivePages: UInt64(stats.inactive_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }
}

// MARK: - Network

/// 读取实时网络累计字节（sysctl NET_RT_IFLIST2，原生 64 位计数器，无 4GB 回绕）。
/// 聚合所有「UP 且非环回」接口；接口热插拔天然容错。
public enum NetworkSnapshotReader {
    public static func read() -> NetworkCounters {
        var mib: [Int32] = [Int32(CTL_NET), Int32(PF_ROUTE), 0, 0, Int32(NET_RT_IFLIST2), 0]
        var needed = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else {
            return NetworkCounters(bytesIn: 0, bytesOut: 0)
        }
        var buffer = [UInt8](repeating: 0, count: needed)
        let status = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctl(&mib, UInt32(mib.count), ptr.baseAddress, &needed, nil, 0)
        }
        guard status == 0 else { return NetworkCounters(bytesIn: 0, bytesOut: 0) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        buffer.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var cursor = base
            let end = base.advanced(by: needed)
            while cursor < end {
                // 公共头部：msglen(UInt16@0)、version(UInt8@2)、type(UInt8@3)
                let msglen = Int(cursor.loadUnaligned(as: UInt16.self))
                guard msglen > 0 else { break }
                let type = cursor.load(fromByteOffset: 3, as: UInt8.self)
                if type == 0x12 { // RTM_IFINFO2 → if_msghdr2（内含 if_data64 64 位计数）
                    let m = cursor.loadUnaligned(as: if_msghdr2.self)
                    let isUp = (m.ifm_flags & 0x1) != 0 // IFF_UP
                    let isLoopback = (m.ifm_flags & 0x8) != 0 // IFF_LOOPBACK
                    if isUp, !isLoopback {
                        bytesIn &+= m.ifm_data.ifi_ibytes
                        bytesOut &+= m.ifm_data.ifi_obytes
                    }
                }
                cursor = cursor.advanced(by: msglen)
            }
        }
        return NetworkCounters(bytesIn: bytesIn, bytesOut: bytesOut)
    }
}
