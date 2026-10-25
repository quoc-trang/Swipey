import Foundation
import Photos
import SwiftUI

@Observable
public final class ReviewViewModel {
    public var markedItems: [PhotoItem]
    public var selectedIds: Set<String>
    public var isDeleting: Bool = false
    public var isSuccess: Bool = false
    public var errorMessage: String? = nil

    // Success metrics snapshot
    public var successfullyDeletedCount: Int = 0
    public var successfullySavedBytes: Int64 = 0

    private let photoService: PhotoLibraryService
    private let statsManager: StatsManager
    public let isMockMode: Bool

    public init(
        markedItems: [PhotoItem],
        photoService: PhotoLibraryService = .shared,
        statsManager: StatsManager = .shared,
        isMockMode: Bool = false
    ) {
        self.markedItems = markedItems
        self.selectedIds = Set(markedItems.map { $0.id })
        self.photoService = photoService
        self.statsManager = statsManager
        self.isMockMode = isMockMode
    }

    public var selectedItems: [PhotoItem] {
        markedItems.filter { selectedIds.contains($0.id) }
    }

    public var selectedCount: Int {
        selectedIds.count
    }

    public var estimatedStorageFreedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.estimatedFileSize }
    }

    public var formattedStorageFreed: String {
        ByteCountFormatter.string(fromByteCount: estimatedStorageFreedBytes, countStyle: .file)
    }

    public func toggleSelection(for item: PhotoItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    public func selectAll() {
        selectedIds = Set(markedItems.map { $0.id })
    }

    public func deselectAll() {
        selectedIds.removeAll()
    }

    /// Deletes all selected photos in a single batch operation.
    @MainActor
    public func executeDeletion() async -> Bool {
        guard !selectedItems.isEmpty else { return false }
        isDeleting = true
        errorMessage = nil

        let countToDelete = selectedCount
        let bytesToDelete = estimatedStorageFreedBytes

        if isMockMode {
            // Simulate deletion in mock/preview mode
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.successfullyDeletedCount = countToDelete
            self.successfullySavedBytes = bytesToDelete
            self.statsManager.recordDeletion(count: countToDelete, bytesFreed: bytesToDelete)
            self.markedItems.removeAll { selectedIds.contains($0.id) }
            self.selectedIds.removeAll()
            self.isDeleting = false
            self.isSuccess = true
            HapticService.shared.deletionCompleted()
            return true
        }

        let assetsToDelete = selectedItems.compactMap { $0.asset }
        do {
            let success = try await photoService.deleteAssets(assetsToDelete)
            if success {
                self.successfullyDeletedCount = countToDelete
                self.successfullySavedBytes = bytesToDelete
                self.statsManager.recordDeletion(count: countToDelete, bytesFreed: bytesToDelete)
                self.markedItems.removeAll { selectedIds.contains($0.id) }
                self.selectedIds.removeAll()
                self.isSuccess = true
                HapticService.shared.deletionCompleted()
            }
            self.isDeleting = false
            return success
        } catch {
            self.errorMessage = error.localizedDescription
            self.isDeleting = false
            return false
        }
    }
}
