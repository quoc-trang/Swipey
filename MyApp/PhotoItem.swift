import Foundation
import Photos
import UIKit

/// Represents a photo or video item in the swipe clean queue.
/// Supports both real PHAsset instances and mock data for SwiftUI previews and testing.
public struct PhotoItem: Identifiable, Hashable {
    public let id: String
    public let asset: PHAsset?
    public let creationDate: Date?
    public let mediaType: PHAssetMediaType
    public let isScreenshot: Bool
    public let isFavorite: Bool
    public let duration: TimeInterval
    public let pixelWidth: Int
    public let pixelHeight: Int
    public var estimatedFileSize: Int64
    public let mockImage: UIImage?

    public init(asset: PHAsset, estimatedFileSize: Int64 = 0) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
        self.mediaType = asset.mediaType
        self.isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        self.isFavorite = asset.isFavorite
        self.duration = asset.duration
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.estimatedFileSize = estimatedFileSize
        self.mockImage = nil
    }

    /// Mock initializer for SwiftUI previews & unit testing without Photo Library access.
    public init(
        id: String = UUID().uuidString,
        creationDate: Date = Date(),
        mediaType: PHAssetMediaType = .image,
        isScreenshot: Bool = false,
        isFavorite: Bool = false,
        duration: TimeInterval = 0,
        pixelWidth: Int = 1920,
        pixelHeight: Int = 1080,
        estimatedFileSize: Int64 = 2_500_000,
        mockImage: UIImage? = nil
    ) {
        self.id = id
        self.asset = nil
        self.creationDate = creationDate
        self.mediaType = mediaType
        self.isScreenshot = isScreenshot
        self.isFavorite = isFavorite
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.estimatedFileSize = estimatedFileSize
        self.mockImage = mockImage
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Mock Helpers
extension PhotoItem {
    public static func mockSamples() -> [PhotoItem] {
        let colors: [(UIColor, String, Bool, TimeInterval, Int64)] = [
            (.systemBlue, "Beach Sunset", false, 0, 3_400_000),
            (.systemPurple, "Receipt Screenshot", true, 0, 850_000),
            (.systemTeal, "Mountain Trip Video", false, 45.2, 54_000_000),
            (.systemIndigo, "City Skyline", false, 0, 4_100_000),
            (.systemOrange, "Dog in Park", false, 0, 2_900_000),
            (.systemPink, "Concert Clip", false, 18.0, 28_000_000),
            (.systemGreen, "Coffee Shop", false, 0, 1_800_000),
            (.systemYellow, "Ticket Screenshot", true, 0, 720_000)
        ]

        return colors.enumerated().map { index, config in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
            let img = renderer.image { ctx in
                config.0.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))

                let text = "\(config.1)\n#\(index + 1)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.boldSystemFont(ofSize: 32)
                ]
                let str = NSAttributedString(string: text, attributes: attrs)
                str.draw(at: CGPoint(x: 40, y: 350))
            }

            return PhotoItem(
                id: "mock_\(index)",
                creationDate: Calendar.current.date(byAdding: .day, value: -index * 3, to: Date()) ?? Date(),
                mediaType: config.3 > 0 ? .video : .image,
                isScreenshot: config.2,
                isFavorite: index == 0,
                duration: config.3,
                pixelWidth: 1920,
                pixelHeight: 1080,
                estimatedFileSize: config.4,
                mockImage: img
            )
        }
    }
}
