import SwiftUI

public struct SwipeStackView: View {
    @Bindable var viewModel: SwipeViewModel
    var onReviewTapped: () -> Void = {}

    public init(viewModel: SwipeViewModel, onReviewTapped: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onReviewTapped = onReviewTapped
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Card Stack Area
                ZStack {
                    if viewModel.isLoading {
                        loadingStateView
                    } else if viewModel.visibleCards.isEmpty {
                        emptyStateView
                    } else {
                        // Display back cards first so the top card sits on top
                        ForEach(Array(viewModel.visibleCards.enumerated().reversed()), id: \.element.id) { index, item in
                            let isTop = index == 0
                            let scale = 1.0 - (Double(index) * 0.04)
                            let yOffset = Double(index) * 10.0

                            SwipeCardView(item: item, isTopCard: isTop) { direction in
                                viewModel.swipe(item: item, direction: direction)
                            }
                            .frame(
                                width: min(geometry.size.width - 32, 420),
                                height: min(geometry.size.height - 130, 560)
                            )
                            .scaleEffect(scale)
                            .offset(y: yOffset)
                            .zIndex(Double(viewModel.visibleCards.count - index))
                            .allowsHitTesting(isTop)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Action Bar (Buttons as accessible alternative to gestures)
                if !viewModel.visibleCards.isEmpty {
                    actionBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 28) {
            // Delete button (accessible alternative)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.swipeCurrent(direction: .delete)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 68, height: 68)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            .accessibilityLabel("Mark photo for deletion")
            .accessibilityHint("Swipes left and queues this photo for deletion")

            // Undo button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    viewModel.undo()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(width: 50, height: 50)

                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(viewModel.canUndo ? Color.primary : Color.secondary.opacity(0.5))
                }
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("Undo last swipe")
            .accessibilityHint("Restores the last photo swiped")

            // Keep button (accessible alternative)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.swipeCurrent(direction: .keep)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 68, height: 68)

                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .accessibilityLabel("Keep photo")
            .accessibilityHint("Swipes right and retains this photo in your library")
        }
    }

    // MARK: - Loading State
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your photos…")
                .font(.headline)
            Text("Swipey is preparing your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading your photos")
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: viewModel.remainingCount)

            VStack(spacing: 8) {
                Text("All Caught Up!")
                    .font(.title2.bold())

                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !viewModel.toDelete.isEmpty {
                Button(action: onReviewTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.circle.fill")
                        Text("Review & Delete (\(viewModel.toDelete.count))")
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.top, 8)
            }

            Button {
                viewModel.reload()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Check for New Photos")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.horizontal, 24)
    }

    private var emptyStateSubtitle: String {
        if !viewModel.toDelete.isEmpty {
            let size = ByteCountFormatter.string(fromByteCount: viewModel.estimatedFreedBytes, countStyle: .file)
            return "You've marked \(viewModel.toDelete.count) photos for deletion, freeing ~\(size). Review them to commit changes."
        } else {
            return "No more photos to review in this category. You can choose another filter or celebrate your clean library!"
        }
    }
}

#Preview {
    let vm = SwipeViewModel(isMockMode: true)
    vm.loadMockData()
    return SwipeStackView(viewModel: vm)
}
