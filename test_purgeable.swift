import Foundation

let rootURL = URL(fileURLWithPath: NSHomeDirectory())
let values = try rootURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeTotalCapacityKey])
print("Important: \(values.volumeAvailableCapacityForImportantUsage ?? 0)")
print("Available: \(values.volumeAvailableCapacity ?? 0)")
print("Total: \(values.volumeTotalCapacity ?? 0)")
