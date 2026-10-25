import Foundation
import Photos
import SwiftUI

public enum SwipeDirection {
    case keep
    case delete
}

public struct SwipeHistoryRecord {
    public let item: PhotoItem
    public let action: SwipeDirection
    public let index: Int
}

@MainActor
@Observable
public final class SwipeViewModel {
    public var assets: [PhotoItem] = []
    public var currentIndex: Int = 0
    public var toDelete: [PhotoItem] = []
    public var kept: Set<String> = []
    public var history: [SwipeHistoryRecord] = []
    public var isLoading: Bool = false
    public var isMockMode: Bool = false

    // Filters
    public var selectedCategory: MediaCategory = .all {
        didSet {
            if oldValue != selectedCategory {
                reload()
            }
        }
    }
    public var selectedMonthYear: MonthYearFilter? = nil {
        didSet {
            if oldValue != selectedMonthYear {
                reload()
            }
        }
    }

    private let userDefaultsKeptKey = "swipeclean_kept_asset_ids"
    private let photoService: PhotoLibraryService
    private let imageLoader: ImageLoader
    private var reloadGeneration = 0

    public init(
        photoService: PhotoLibraryService? = nil,
        imageLoader: ImageLoader? = nil,
        isMockMode: Bool = false
    ) {
        self.photoService = photoService ?? PhotoLibraryService.shared
        self.imageLoader = imageLoader ?? ImageLoader.shared
        self.isMockMode = isMockMode
        self.loadKeptIdentifiers()
    }

    // MARK: - Persistence
    private func loadKeptIdentifiers() {
        if let saved = UserDefaults.standard.array(forKey: userDefaultsKeptKey) as? [String] {
            self.kept = Set(saved)
        }
    }

    private func saveKeptIdentifiers() {
        UserDefaults.standard.set(Array(kept), forKey: userDefaultsKeptKey)
    }

    // MARK: - Current Visible Items
    /// The top 2–3 cards in the visible stack
    public var visibleCards: [PhotoItem] {
        guard currentIndex < assets.count else { return [] }
        let end = min(currentIndex + 3, assets.count)
        return Array(assets[currentIndex..<end])
    }

    public var currentCard: PhotoItem? {
        guard currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    public var remainingCount: Int {
        max(0, assets.count - currentIndex)
    }

    public var canUndo: Bool {
        !history.isEmpty
    }

    public var estimatedFreedBytes: Int64 {
        toDelete.reduce(0) { $0 + $1.estimatedFileSize }
    }

    // MARK: - Data Loading
    public func reload() {
        if isMockMode {
            loadMockData()
            return
        }

        isLoading = true
        reloadGeneration += 1
        let generation = reloadGeneration
        let photoService = photoService
        let excludedIds = kept
        let selectedCategory = selectedCategory
        let selectedMonthYear = selectedMonthYear

        var startDate: Date? = nil
        var endDate: Date? = nil

        if let my = selectedMonthYear {
            var comps = DateComponents()
            comps.year = my.year
            comps.month = my.month
            comps.day = 1
            if let start = Calendar.current.date(from: comps) {
                startDate = start
                if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start) {
                    endDate = Calendar.current.date(byAdding: .second, value: -1, to: nextMonth)
                }
            }
        }

        let onlyScreenshots = selectedCategory == .screenshots
        let onlyVideos = selectedCategory == .videos
        let onlySelfies = selectedCategory == .selfies

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fetched = photoService.fetchAssets(
                onlyScreenshots: onlyScreenshots,
                onlyVideos: onlyVideos,
                onlySelfies: onlySelfies,
                startDate: startDate,
                endDate: endDate,
                excludedIds: excludedIds
            )

            DispatchQueue.main.async {
                guard self.reloadGeneration == generation else { return }
                self.assets = fetched
                self.currentIndex = 0
                self.isLoading = false
                self.preloadUpcoming()
            }
        }
    }

    public func loadMockData(samples: [PhotoItem]? = nil) {
        self.isMockMode = true
        self.assets = samples ?? PhotoItem.mockSamples()
        self.currentIndex = 0
        self.isLoading = false
    }

    // MARK: - Swipe Actions
    public func swipeCurrent(direction: SwipeDirection) {
        guard currentIndex < assets.count else { return }
        let item = assets[currentIndex]
        swipe(item: item, direction: direction)
    }

    public func swipe(item: PhotoItem, direction: SwipeDirection) {
        let record = SwipeHistoryRecord(item: item, action: direction, index: currentIndex)
        history.append(record)

        switch direction {
        case .keep:
            kept.insert(item.id)
            saveKeptIdentifiers()
            HapticService.shared.swipeKeep()

        case .delete:
            var itemToDelete = item
            if itemToDelete.estimatedFileSize == 0, let asset = itemToDelete.asset {
                itemToDelete.estimatedFileSize = photoService.estimateFileSize(for: asset)
            }
            if !toDelete.contains(where: { $0.id == itemToDelete.id }) {
                toDelete.append(itemToDelete)
            }
            HapticService.shared.swipeDelete()
        }

        currentIndex += 1
        preloadUpcoming()
    }

    public func undo() {
        guard let lastRecord = history.popLast() else { return }

        switch lastRecord.action {
        case .keep:
            kept.remove(lastRecord.item.id)
            saveKeptIdentifiers()
        case .delete:
            toDelete.removeAll { $0.id == lastRecord.item.id }
        }

        if currentIndex > 0 {
            currentIndex -= 1
        }

        HapticService.shared.undo()
        preloadUpcoming()
    }

    // MARK: - Preloading
    private func preloadUpcoming() {
        guard !isMockMode else { return }
        let startIndex = currentIndex
        let endIndex = min(startIndex + 5, assets.count)
        guard startIndex < endIndex else { return }
        let slice = Array(assets[startIndex..<endIndex])
        imageLoader.preloadImages(for: slice)
    }

    public func resetKeptHistory() {
        kept.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKeptKey)
        reload()
    }
}
