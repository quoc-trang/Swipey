import Foundation
import Photos
import SwiftUI

/// Service responsible for communicating with PhotoKit, managing authorization,
/// fetching photos, calculating storage usage, and executing batch deletions.
@Observable
public final class PhotoLibraryService: NSObject, @unchecked Sendable, PHPhotoLibraryChangeObserver {
    public static let shared = PhotoLibraryService()

    public var authorizationStatus: PHAuthorizationStatus = .notDetermined
    public var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    public override init() {
        super.init()
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Authorization
    @MainActor
    public func checkAuthorization() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    @MainActor
    public func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        return status
    }

    // MARK: - Fetching Assets
    /// Fetches assets sorted by newest first, optionally filtering by smart album/criteria and excluding kept IDs.
    public func fetchAssets(
        mediaType: PHAssetMediaType? = nil,
        onlyScreenshots: Bool = false,
        onlyVideos: Bool = false,
        onlySelfies: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        excludedIds: Set<String> = []
    ) -> [PhotoItem] {
        guard isAuthorized else { return [] }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var predicates: [NSPredicate] = []

        if onlyVideos {
            predicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue))
        } else if let mediaType = mediaType {
            predicates.append(NSPredicate(format: "mediaType == %d", mediaType.rawValue))
        }

        if onlyScreenshots {
            predicates.append(NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue))
        }

        if startDate != nil || endDate != nil {
            if let start = startDate {
                predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
            }
            if let end = endDate {
                predicates.append(NSPredicate(format: "creationDate <= %@", end as NSDate))
            }
        }

        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        let fetchResult: PHFetchResult<PHAsset>
        if onlySelfies {
            let selfieCollections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumSelfPortraits,
                options: nil
            )
            if let selfieAlbum = selfieCollections.firstObject {
                fetchResult = PHAsset.fetchAssets(in: selfieAlbum, options: options)
            } else {
                fetchResult = PHAsset.fetchAssets(with: options)
            }
        } else {
            fetchResult = PHAsset.fetchAssets(with: options)
        }

        var items: [PhotoItem] = []
        items.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            if !excludedIds.contains(asset.localIdentifier) {
                // File size is calculated lazily when an item is marked for deletion.
                // Avoiding this per-asset PhotoKit lookup keeps initial loading fast.
                items.append(PhotoItem(asset: asset))
            }
        }

        return items
    }

    // MARK: - File Size Estimation
    public func estimateFileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            if let fileSizeNumber = resource.value(forKey: "fileSize") as? NSNumber, fileSizeNumber.int64Value > 0 {
                return fileSizeNumber.int64Value
            }
        }
        // Fallback estimate based on dimensions
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000.0
        if asset.mediaType == .video {
            return Int64(max(1, asset.duration) * 2_500_000) // approx 2.5MB per second
        } else {
            return Int64(max(1.0, megapixels) * 1_200_000) // approx 1.2MB per megapixel
        }
    }

    // MARK: - Batch Deletion
    /// Deletes the provided assets in a SINGLE batch operation so iOS prompts once.
    public func deleteAssets(_ assets: [PHAsset]) async throws -> Bool {
        guard !assets.isEmpty else { return true }

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - PHPhotoLibraryChangeObserver
    nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.checkAuthorization()
        }
    }
}
