//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation
import Darwin
import IOKit

// H5: Removed @MainActor — this service performs blocking I/O (Mach kernel calls,
// getifaddrs, FileManager) and is called from within a Task in AppViewModel.
// Running on @MainActor would unnecessarily block the main thread.
actor SystemMonitorService {
    static let shared = SystemMonitorService()

    private var prevCPUInfo: host_cpu_load_info?
    private var smcConnection: io_connect_t = 0
    private var smcOpened = false

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

    // MARK: - CPU Temperature via SMC
    // Uses IOKit to read Apple SMC (System Management Controller) temperature sensors.
    // Works on both Intel and Apple Silicon without root privileges.

    private struct SMCKeyData {
        struct Vers {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }
        struct PLimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }
        struct KeyInfo {
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        var key: UInt32 = 0
        var vers: Vers = Vers()
        var pLimitData: PLimitData = PLimitData()
        var keyInfo: KeyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private static let smcKernelIndexRead: UInt8 = 5

    private func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }

    deinit {
        if smcOpened {
            IOServiceClose(smcConnection)
        }
    }

    private func openSMC() -> Bool {
        if smcOpened { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        smcOpened = (result == kIOReturnSuccess)
        return smcOpened
    }

    private func readSMCKey(_ key: String) -> Double? {
        guard openSMC() else { return nil }

        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        inputStruct.key = fourCharCode(key)
        inputStruct.data8 = Self.smcKernelIndexRead

        var outputSize = MemoryLayout<SMCKeyData>.size
        let result = withUnsafeMutablePointer(to: &inputStruct) { inPtr in
            withUnsafeMutablePointer(to: &outputStruct) { outPtr in
                IOConnectCallStructMethod(
                    smcConnection,
                    2, // kSMCHandleYPCEvent
                    inPtr,
                    MemoryLayout<SMCKeyData>.size,
                    outPtr,
                    &outputSize
                )
            }
        }

        guard result == kIOReturnSuccess else { return nil }

        // Read data size for this key
        let dataSize = outputStruct.keyInfo.dataSize
        guard dataSize >= 2 else { return nil }

        // Now do the actual read
        var readInput = SMCKeyData()
        var readOutput = SMCKeyData()
        readInput.key = fourCharCode(key)
        readInput.keyInfo.dataSize = dataSize
        readInput.data8 = Self.smcKernelIndexRead

        outputSize = MemoryLayout<SMCKeyData>.size
        let readResult = withUnsafeMutablePointer(to: &readInput) { inPtr in
            withUnsafeMutablePointer(to: &readOutput) { outPtr in
                IOConnectCallStructMethod(
                    smcConnection,
                    2,
                    inPtr,
                    MemoryLayout<SMCKeyData>.size,
                    outPtr,
                    &outputSize
                )
            }
        }

        guard readResult == kIOReturnSuccess else { return nil }

        // Interpret as sp78 (signed 7.8 fixed point) or flt (float)
        let b0 = readOutput.bytes.0
        let b1 = readOutput.bytes.1
        let temp = Double(Int16(b0) << 8 | Int16(b1)) / 256.0

        // Sanity check: valid CPU temps are between 0°C and 120°C
        guard temp > 0 && temp < 120 else { return nil }
        return temp
    }

    private func getCPUTemperature() -> Double? {
        // Try common Apple SMC keys for CPU temperature
        // TC0P = CPU proximity, TC0D = CPU die, Tp09/Tp0T = Apple Silicon efficiency/performance cores
        for key in ["TC0P", "TC0D", "Tp09", "Tp0T", "TC0E", "TC0F"] {
            if let temp = readSMCKey(key) {
                return temp
            }
        }
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
    /// Returns disk total/free/used matching macOS System Settings.
    /// Uses `volumeAvailableCapacityForImportantUsage` which includes purgeable space,
    /// consistent with what macOS Settings > General > Storage displays.
    nonisolated func getDiskInfo() -> (total: Int64, free: Int64, used: Int64) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) {
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            return (total, free, max(0, total - free))
        }
        // Fallback to FileManager
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
