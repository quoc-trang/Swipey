import SwiftUI
import Photos

public struct SwipeCardView: View {
    let item: PhotoItem
    let isTopCard: Bool
    var onSwiped: ((SwipeDirection) -> Void)?

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var loadedImage: UIImage? = nil
    @State private var imageRequestId: PHImageRequestID? = nil
    @State private var isShowingFullScreen = false

    private let swipeThreshold: CGFloat = 120.0

    public init(
        item: PhotoItem,
        isTopCard: Bool = true,
        onSwiped: ((SwipeDirection) -> Void)? = nil
    ) {
        self.item = item
        self.isTopCard = isTopCard
        self.onSwiped = onSwiped
    }

    public var body: some View {
        GeometryReader { proxy in
            let cardSize = proxy.size

            ZStack {
                // Card Background & Image
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .shadow(color: Color.black.opacity(isTopCard ? 0.14 : 0.06), radius: isTopCard ? 12 : 6, x: 0, y: isTopCard ? 6 : 3)

                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Top & Bottom Gradients for readable badges
                VStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 90)

                    Spacer()

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)

                // Metadata Badges (Top & Bottom)
                VStack {
                    topBadges
                    Spacer()
                    bottomBadges
                }
                .padding(16)
                .allowsHitTesting(false)

                // KEEP Overlay (Visible when dragging right)
                keepOverlay
                    .opacity(keepOverlayOpacity)
                    .allowsHitTesting(false)

                // DELETE Overlay (Visible when dragging left)
                deleteOverlay
                    .opacity(deleteOverlayOpacity)
                    .allowsHitTesting(false)

                // Drag color tint
                dragTintOverlay
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(false)
            }
            .frame(width: cardSize.width, height: cardSize.height)
            .offset(x: dragOffset.width, y: dragOffset.height * 0.4)
            .rotationEffect(.degrees(Double(dragOffset.width / 18.0)))
            .gesture(
                isTopCard ? dragGesture(width: cardSize.width) : nil
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard isTopCard, !isDragging else { return }
                    isShowingFullScreen = true
                }
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.72), value: dragOffset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Tap to view full screen. Swipe right to keep, swipe left to delete.")
            .fullScreenCover(isPresented: $isShowingFullScreen) {
                FullScreenPhotoView(
                    image: loadedImage,
                    accessibilityLabel: accessibilityDescription
                )
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            ImageLoader.shared.cancelRequest(imageRequestId)
        }
    }

    // MARK: - Overlays
    private var keepOverlayOpacity: Double {
        guard dragOffset.width > 0 else { return 0 }
        return min(Double(dragOffset.width / swipeThreshold), 1.0)
    }

    private var deleteOverlayOpacity: Double {
        guard dragOffset.width < 0 else { return 0 }
        return min(Double(abs(dragOffset.width) / swipeThreshold), 1.0)
    }

    private var dragTintOverlay: some View {
        Group {
            if dragOffset.width > 0 {
                Color.green.opacity(Double(dragOffset.width / (swipeThreshold * 4.0)))
            } else if dragOffset.width < 0 {
                Color.red.opacity(Double(abs(dragOffset.width) / (swipeThreshold * 4.0)))
            } else {
                Color.clear
            }
        }
    }

    private var keepOverlay: some View {
        VStack {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("KEEP")
                        .fontWeight(.black)
                        .tracking(2)
                }
                .font(.system(size: 24))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundStyle(.green)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.green, lineWidth: 3))
                .shadow(color: .green.opacity(0.4), radius: 8)
                .padding(20)

                Spacer()
            }
            Spacer()
        }
    }

    private var deleteOverlay: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 8) {
                    Text("DELETE")
                        .fontWeight(.black)
                        .tracking(2)
                    Image(systemName: "trash.fill")
                }
                .font(.system(size: 24))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.red, lineWidth: 3))
                .shadow(color: .red.opacity(0.4), radius: 8)
                .padding(20)
            }
            Spacer()
        }
    }

    // MARK: - Badges
    private var topBadges: some View {
        HStack(spacing: 8) {
            if item.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            if item.isScreenshot {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                    Text("Screenshot")
                }
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            if item.mediaType == .video {
                HStack(spacing: 4) {
                    Image(systemName: "video.fill")
                    Text(formatDuration(item.duration))
                }
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            Spacer()

            // File size badge
            Text(ByteCountFormatter.string(fromByteCount: item.estimatedFileSize, countStyle: .file))
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }

    private var bottomBadges: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let date = item.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Text("\(item.pixelWidth) × \(item.pixelHeight)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
        }
    }

    // MARK: - Drag Gesture
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                dragOffset = gesture.translation
                isDragging = true
            }
            .onEnded { gesture in
                let translationX = gesture.translation.width
                if translationX > swipeThreshold {
                    // Fly off to right (KEEP)
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = CGSize(width: width * 1.5, height: gesture.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwiped?(.keep)
                    }
                } else if translationX < -swipeThreshold {
                    // Fly off to left (DELETE)
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = CGSize(width: -width * 1.5, height: gesture.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwiped?(.delete)
                    }
                } else {
                    // Spring back
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                        dragOffset = .zero
                    }
                }
                isDragging = false
            }
    }

    // MARK: - Image Loading
    private func loadImage() {
        if let mock = item.mockImage {
            self.loadedImage = mock
            return
        }

        imageRequestId = ImageLoader.shared.loadImage(for: item) { image in
            self.loadedImage = image
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var accessibilityDescription: String {
        let type = item.mediaType == .video ? "Video" : (item.isScreenshot ? "Screenshot" : "Photo")
        let dateStr = item.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "unknown date"
        let sizeStr = ByteCountFormatter.string(fromByteCount: item.estimatedFileSize, countStyle: .file)
        return "\(type), taken \(dateStr), size \(sizeStr)"
    }
}

private struct FullScreenPhotoView: View {
    let image: UIImage?
    let accessibilityLabel: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(accessibilityLabel)
            } else {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Loading photo")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close photo")
            .padding()
        }
    }
}

#Preview {
    let mock = PhotoItem.mockSamples().first!
    return SwipeCardView(item: mock, isTopCard: true)
        .frame(width: 340, height: 480)
        .padding()
}
