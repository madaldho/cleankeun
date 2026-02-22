//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation
import Darwin

class MemoryService {
    static let shared = MemoryService()

    func getMemoryInfo() -> MemoryInfo {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(hostPort, HOST_VM_INFO64, ptr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryInfo(total: totalMemory, used: 0, free: totalMemory, wired: 0, active: 0, inactive: 0, compressed: 0, appMemory: 0)
        }
        let ps = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * ps
        let inactive = UInt64(stats.inactive_count) * ps
        let wired = UInt64(stats.wire_count) * ps
        let compressed = UInt64(stats.compressor_page_count) * ps
        let free = UInt64(stats.free_count) * ps
        let used = active + wired + compressed
        // BUG-31 fix: prevent UInt64 underflow
        let internalMem = UInt64(stats.internal_page_count) * ps
        let purgeableMem = UInt64(stats.purgeable_count) * ps
        let appMem = internalMem >= purgeableMem ? internalMem - purgeableMem : 0

        return MemoryInfo(total: totalMemory, used: used, free: free + inactive, wired: wired, active: active, inactive: inactive, compressed: compressed, appMemory: appMem)
    }

    // BUG-06 fix: run Process on background thread to avoid blocking main thread
    func optimizeMemory() async -> (before: MemoryInfo, after: MemoryInfo) {
        let before = getMemoryInfo()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch { }
                cont.resume()
            }
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let after = getMemoryInfo()
        return (before, after)
    }
}
