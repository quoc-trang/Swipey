import Foundation
import Photos
import SwiftUI
import UIKit

/// Manages caching and loading of photo thumbnails using PHCachingImageManager.
/// Ensures thumbnail sizes are loaded rather than full-resolution images,
/// with iCloud network access enabled and asynchronous preheating.
@Observable
public final class ImageLoader {
    public static let shared = ImageLoader()

    private let cachingManager = PHCachingImageManager()
    public static let defaultThumbnailSize = CGSize(width: 800, height: 1100)

    public init() {}

    /// Requests an image for a PhotoItem. Returns an image request ID if requested from PHCachingImageManager.
    @discardableResult
    public func loadImage(
        for item: PhotoItem,
        targetSize: CGSize = defaultThumbnailSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID? {
        if let mock = item.mockImage {
            completion(mock)
            return nil
        }

        guard let asset = item.asset else {
            completion(nil)
            return nil
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false

        return cachingManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Preloads and caches thumbnails for the upcoming assets (e.g. next 5 cards).
    public func preloadImages(for items: [PhotoItem], targetSize: CGSize = defaultThumbnailSize) {
        let assets = items.compactMap { $0.asset }
        guard !assets.isEmpty else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    /// Stops caching images when cards are swiped or removed.
    public func stopPreloadImages(for items: [PhotoItem], targetSize: CGSize = defaultThumbnailSize) {
        let assets = items.compactMap { $0.asset }
        guard !assets.isEmpty else { return }

        cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    /// Cancels a specific in-flight image request.
    public func cancelRequest(_ requestId: PHImageRequestID?) {
        guard let id = requestId else { return }
        cachingManager.cancelImageRequest(id)
    }
}
