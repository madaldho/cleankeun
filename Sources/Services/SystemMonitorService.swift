//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation
import Darwin

class SystemMonitorService {
    static let shared = SystemMonitorService()

    private var prevCPUInfo: host_cpu_load_info?

    // MARK: - CPU Info
    func getCPUInfo() -> CPUInfo {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUInfo(usagePercentage: 0, userPercentage: 0, systemPercentage: 0, idlePercentage: 100, coreCount: ProcessInfo.processInfo.processorCount, temperature: nil)
        }

        let user: Double
        let system: Double
        let idle: Double

        if let prev = prevCPUInfo {
            let userDiff = Double(cpuInfo.cpu_ticks.0 &- prev.cpu_ticks.0)
            let systemDiff = Double(cpuInfo.cpu_ticks.1 &- prev.cpu_ticks.1)
            let idleDiff = Double(cpuInfo.cpu_ticks.2 &- prev.cpu_ticks.2)
            let niceDiff = Double(cpuInfo.cpu_ticks.3 &- prev.cpu_ticks.3)
            let total = userDiff + systemDiff + idleDiff + niceDiff
            user = total > 0 ? (userDiff / total) * 100 : 0
            system = total > 0 ? (systemDiff / total) * 100 : 0
            idle = total > 0 ? (idleDiff / total) * 100 : 0
        } else {
            let total = Double(cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2 + cpuInfo.cpu_ticks.3)
            user = total > 0 ? (Double(cpuInfo.cpu_ticks.0) / total) * 100 : 0
            system = total > 0 ? (Double(cpuInfo.cpu_ticks.1) / total) * 100 : 0
            idle = total > 0 ? (Double(cpuInfo.cpu_ticks.2) / total) * 100 : 0
        }

        prevCPUInfo = cpuInfo

        return CPUInfo(
            usagePercentage: min(user + system, 100),
            userPercentage: user,
            systemPercentage: system,
            idlePercentage: idle,
            coreCount: ProcessInfo.processInfo.processorCount,
            temperature: getCPUTemperature()
        )
    }

    private func getCPUTemperature() -> Double? {
        return nil
    }

    // MARK: - Network Speed
    private var prevNetworkBytes: (rx: UInt64, tx: UInt64, time: Date)?

    func getNetworkSpeed() -> NetworkInfo {
        let (rx, tx) = getNetworkBytes()
        let now = Date()

        defer {
            prevNetworkBytes = (rx, tx, now)
        }

        guard let prev = prevNetworkBytes else {
            return NetworkInfo(uploadSpeed: 0, downloadSpeed: 0)
        }

        let elapsed = now.timeIntervalSince(prev.time)
        guard elapsed > 0 else {
            return NetworkInfo(uploadSpeed: 0, downloadSpeed: 0)
        }

        // BUG-01 fix: guard against counter wraparound
        let downloadSpeed = rx >= prev.rx ? Int64(Double(rx - prev.rx) / elapsed) : 0
        let uploadSpeed = tx >= prev.tx ? Int64(Double(tx - prev.tx) / elapsed) : 0

        return NetworkInfo(
            uploadSpeed: max(0, uploadSpeed),
            downloadSpeed: max(0, downloadSpeed)
        )
    }

    private func getNetworkBytes() -> (rx: UInt64, tx: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0

        var ptr = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("lo") {
                if ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    // BUG-02 fix: guard against nil ifa_data
                    if let ifaData = ptr.pointee.ifa_data {
                        let data = ifaData.assumingMemoryBound(to: if_data.self)
                        rx += UInt64(data.pointee.ifi_ibytes)
                        tx += UInt64(data.pointee.ifi_obytes)
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return (rx, tx)
    }

    // MARK: - Disk Info
    func getDiskInfo() -> (total: Int64, free: Int64, used: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            return (total, free, total - free)
        } catch {
            return (0, 0, 0)
        }
    }
}
