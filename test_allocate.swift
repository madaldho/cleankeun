import Foundation

func allocateSpace() {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dummy_test")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    guard let handle = try? FileHandle(forWritingTo: url) else { return }
    let fd = handle.fileDescriptor
    var store = fstore_t()
    store.fst_flags = Int32(F_ALLOCATECONTIG)
    store.fst_posmode = Int32(F_PEOFPOSMODE)
    store.fst_offset = 0
    store.fst_length = 5 * 1024 * 1024 * 1024 // 5GB
    
    let result = fcntl(fd, F_PREALLOCATE, &store)
    if result == -1 {
        // Fallback to ALLOCATEALL
        store.fst_flags = Int32(F_ALLOCATEALL)
        let res2 = fcntl(fd, F_PREALLOCATE, &store)
        print("Fallback result: \(res2)")
    } else {
        print("Allocated 5GB contiguously")
    }
    
    // Check size
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    print("Size: \(attrs?[.size] ?? 0)")
    
    // Clean up
    try? FileManager.default.removeItem(at: url)
}

allocateSpace()
