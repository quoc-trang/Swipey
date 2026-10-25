import SwiftUI
import Photos

public struct ReviewGridView: View {
    @Bindable var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    var onComplete: (([PhotoItem]) -> Void)?

    @State private var showConfirmDialog: Bool = false
    @State private var columns = [
        GridItem(.adaptive(minimum: 105), spacing: 10)
    ]

    public init(
        viewModel: ReviewViewModel,
        onComplete: (([PhotoItem]) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isSuccess {
                    successView
                } else if viewModel.markedItems.isEmpty {
                    emptyMarkedView
                } else {
                    mainReviewContent
                }
            }
            .navigationTitle("Review & Delete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.isSuccess {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.isSuccess && !viewModel.markedItems.isEmpty {
                        Button(viewModel.selectedCount == viewModel.markedItems.count ? "Deselect All" : "Select All") {
                            if viewModel.selectedCount == viewModel.markedItems.count {
                                viewModel.deselectAll()
                            } else {
                                viewModel.selectAll()
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .alert("Confirm Deletion", isPresented: $showConfirmDialog) {
                Button("Delete \(viewModel.selectedCount) Photos", role: .destructive) {
                    Task {
                        let success = await viewModel.executeDeletion()
                        if success {
                            onComplete?(viewModel.markedItems)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(viewModel.selectedCount) photos? They will be moved to the Recently Deleted album in Photos, where you can recover them for up to 30 days.")
            }
            .alert("Error Deleting Photos", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Main Review Content
    private var mainReviewContent: some View {
        VStack(spacing: 0) {
            // Summary Card
            summaryHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.markedItems) { item in
                        ReviewGridCell(
                            item: item,
                            isSelected: viewModel.selectedIds.contains(item.id)
                        ) {
                            viewModel.toggleSelection(for: item)
                        }
                    }
                }
                .padding(16)
            }

            // Bottom Deletion Button
            VStack(spacing: 8) {
                Button {
                    showConfirmDialog = true
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Delete \(viewModel.selectedCount) Photos")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.selectedCount > 0 ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: viewModel.selectedCount > 0 ? Color.red.opacity(0.3) : Color.clear, radius: 8, y: 4)
                }
                .disabled(viewModel.selectedCount == 0 || viewModel.isDeleting)

                Text("Photos stay in Recently Deleted for 30 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Summary Header
    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.selectedCount) selected for deletion")
                    .font(.subheadline.weight(.semibold))

                Text("Tap any photo to unmark or keep it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Est. Space Freed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.formattedStorageFreed)
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty Marked View
    private var emptyMarkedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("No Photos to Delete")
                .font(.title2.bold())

            Text("You haven't marked any photos for deletion yet. Swipe left on cards in the main feed to queue them here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Back to Photos") {
                dismiss()
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 110, height: 110)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Clean Up Complete!")
                    .font(.title.bold())

                let sizeStr = ByteCountFormatter.string(fromByteCount: viewModel.successfullySavedBytes, countStyle: .file)
                Text("\(viewModel.successfullyDeletedCount) photos deleted • ~\(sizeStr) freed")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)

                    Text("Safety Net: Your deleted photos are stored in the 'Recently Deleted' album in Apple Photos for 30 days before permanent deletion. You can recover them at any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Review Grid Cell
private struct ReviewGridCell: View {
    let item: PhotoItem
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage? = nil

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.red : Color.clear, lineWidth: 3)
                )
                .opacity(isSelected ? 1.0 : 0.45)

                // Selection checkmark
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.red : Color.black.opacity(0.4))
                        .frame(width: 26, height: 26)

                    Image(systemName: isSelected ? "trash.fill" : "circle")
                        .font(.system(size: isSelected ? 12 : 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(6)

                // Bottom size badge
                VStack {
                    Spacer()
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: item.estimatedFileSize, countStyle: .file))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(4)
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if let mock = item.mockImage {
                thumbnail = mock
            } else {
                ImageLoader.shared.loadImage(
                    for: item,
                    targetSize: CGSize(width: 250, height: 250)
                ) { img in
                    thumbnail = img
                }
            }
        }
    }
}

#Preview {
    let samples = PhotoItem.mockSamples()
    let vm = ReviewViewModel(markedItems: samples, isMockMode: true)
    return ReviewGridView(viewModel: vm)
}
