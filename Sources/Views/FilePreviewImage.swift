import SwiftUI
import AppKit

struct FilePreviewImage: View {
    let filePath: String
    let maxSize: CGSize = CGSize(width: 300, height: 300)
    
    @State private var image: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: filePath))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task(id: filePath) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let path = filePath
        // Only attempt to load image for known image types
        let ext = (path as NSString).pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        
        guard imageExtensions.contains(ext) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Load image off the main thread
        let loadedImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let url = URL(string: "file://" + path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!) else { return nil }
            
            // Try to create a thumbnail instead of loading full image
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(maxSize.width, maxSize.height)
            ]
            
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        }.value
        
        if !Task.isCancelled {
            self.image = loadedImage
        }
    }
}
