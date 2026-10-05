import SwiftUI
import UIKit
import ImageIO

// Only list thumbnails are downsampled. Saved files and detail photos stay intact.
struct TripPhotoThumbnail: View {
    let id: String
    var data: Data? = nil
    var url: URL? = nil
    var size: CGFloat = 56
    @State private var image: UIImage?
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 12 * 1024 * 1024
        cache.countLimit = 120
        return cache
    }()
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.secondarySystemBackground)) }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
        .task(id: id) {
            image = nil
            if let cached = Self.cache.object(forKey: id as NSString) { image = cached; return }
            let result = await Task.detached(priority: .utility) {
                let source: CGImageSource?
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                if let url { source = CGImageSourceCreateWithURL(url as CFURL, options) }
                else if let data { source = CGImageSourceCreateWithData(data as CFData, options) }
                else { source = nil }
                guard let source,
                      let small = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 180,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil as UIImage? }
                return UIImage(cgImage: small)
            }.value
            guard !Task.isCancelled, let result else { return }
            Self.cache.setObject(result, forKey: id as NSString, cost: Int(result.size.width * result.size.height * 4))
            image = result
        }
    }
}
