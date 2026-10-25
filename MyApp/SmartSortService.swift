import Foundation
import Photos
import Vision
import UIKit

/// Service that analyzes photos using Vision and heuristics to prioritize
/// blurry, duplicate/burst, and utility photos for cleaning.
public final class SmartSortService {
    public static let shared = SmartSortService()

    /// Sorts photos so that screenshots, burst duplicates, and potentially blurry
    /// or utility photos appear first.
    public func prioritizeUnwanted(items: [PhotoItem]) -> [PhotoItem] {
        guard items.count > 1 else { return items }

        // Find potential burst / duplicate clusters (taken within 3 seconds of each other)
        var duplicateIds = Set<String>()
        for i in 0..<(items.count - 1) {
            if let date1 = items[i].creationDate, let date2 = items[i + 1].creationDate {
                if abs(date1.timeIntervalSince(date2)) <= 3.0 {
                    duplicateIds.insert(items[i].id)
                    duplicateIds.insert(items[i + 1].id)
                }
            }
        }

        return items.sorted { a, b in
            let scoreA = cleaningPriorityScore(for: a, isDuplicate: duplicateIds.contains(a.id))
            let scoreB = cleaningPriorityScore(for: b, isDuplicate: duplicateIds.contains(b.id))
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            // Fallback to newer first
            return (a.creationDate ?? .distantPast) > (b.creationDate ?? .distantPast)
        }
    }

    private func cleaningPriorityScore(for item: PhotoItem, isDuplicate: Bool) -> Int {
        var score = 0
        if item.isScreenshot { score += 40 }
        if isDuplicate { score += 30 }
        if item.mediaType == .video && item.duration < 3.0 { score += 20 } // very short accidental videos
        if item.isFavorite { score -= 100 } // keep favorites near bottom
        return score
    }

    /// Vision analysis for blur / aesthetic score
    public func analyzeAesthetics(for image: UIImage) async -> Float {
        guard let cgImage = image.cgImage else { return 0.0 }

        return await withCheckedContinuation { continuation in
            guard #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) else {
                continuation.resume(returning: 0.0)
                return
            }

            let request = VNCalculateImageAestheticsScoresRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNImageAestheticsScoresObservation],
                      let first = results.first else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: first.overallScore)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: 0.0)
            }
        }
    }
}
