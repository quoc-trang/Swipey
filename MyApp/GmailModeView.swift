import SwiftUI

public struct GmailModeView: View {
    let viewModel: GmailViewModel
    @State private var selectedThread: GmailThread?
    @State private var filter = GmailFilter()
    @State private var showFilterSheet = false
    @State private var showBulkActionSheet = false
    @State private var showDisconnectConfirmation = false

    public init(viewModel: GmailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isConnected {
                connectedContent
            } else {
                connectContent
            }
        }
        .task {
            await viewModel.restoreIfNeeded()
        }
        .overlay(alignment: .bottom) {
            if let progress = viewModel.bulkActionProgress {
                ProgressView(progress)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
            } else if let undoMessage = viewModel.undoMessage {
                GmailUndoBanner(message: undoMessage) {
                    Task {
                        await viewModel.undoTrashBatch()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .toolbar {
            if viewModel.isConnected {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter Gmail")

                    Button("Change account") {
                        showDisconnectConfirmation = true
                    }
                    .font(.caption.weight(.medium))
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            GmailFilterSheet(filter: $filter)
        }
        .sheet(isPresented: $showBulkActionSheet) {
            GmailBulkActionSheet(
                visibleThreads: filteredThreads,
                filter: filter,
                onTrash: { targetThreads in
                    await viewModel.trashThreads(targetThreads)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDisconnectConfirmation) {
            GmailChangeAccountConfirmationView(
                onCancel: {
                    showDisconnectConfirmation = false
                },
                onConfirm: {
                    showDisconnectConfirmation = false
                    viewModel.disconnect()
                    filter = GmailFilter()
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedThread) { thread in
            GmailThreadDetailView(
                thread: thread,
                detail: viewModel.selectedThreadDetail,
                isLoading: viewModel.isLoadingDetail,
                onDismiss: { selectedThread = nil }
            )
            .task {
                await viewModel.loadDetail(for: thread)
            }
        }
        .alert(
            "Gmail Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var connectContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 58))
                .foregroundStyle(.blue)

            Text("Clean your Gmail")
                .font(.title2.bold())

            Text("Swipe left to move conversations to Trash. Swipe right to mark them as read.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)

            Button {
                Task {
                    await viewModel.connect()
                }
            } label: {
                Label("Connect Gmail", systemImage: "envelope.open")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var filteredThreads: [GmailThread] {
        viewModel.threads.filter { filter.matches($0) }
    }

    private var connectedContent: some View {
        Group {
            if viewModel.isLoading && viewModel.threads.isEmpty {
                ProgressView("Loading your inbox…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.threads.isEmpty {
                ContentUnavailableView(
                    "Inbox Is Clear",
                    systemImage: "checkmark.circle",
                    description: Text("There are no inbox conversations to review.")
                )
            } else if filteredThreads.isEmpty {
                ContentUnavailableView(
                    "No Matching Conversations",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try changing or clearing your filters.")
                )
            } else {
                GmailCardStackView(
                    threads: filteredThreads,
                    onOpened: { thread in
                        selectedThread = thread
                    },
                    onSwiped: { thread, direction in
                        Task {
                            switch direction {
                            case .trash:
                                await viewModel.moveToTrash(thread)
                            case .markRead:
                                await viewModel.markAsRead(thread)
                            }
                        }
                    },
                    onBulkActions: {
                        showBulkActionSheet = true
                    },
                    hasMoreThreads: viewModel.hasMoreThreads,
                    isLoading: viewModel.isLoading,
                    onLoadMore: {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                )
            }
        }
        .refreshable {
            await viewModel.reload()
        }
    }
}

private struct GmailCardStackView: View {
    let threads: [GmailThread]
    var onOpened: (GmailThread) -> Void
    var onSwiped: (GmailThread, GmailSwipeDirection) -> Void
    var onBulkActions: () -> Void
    let hasMoreThreads: Bool
    let isLoading: Bool
    var onLoadMore: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Text("\(threads.count) conversations loaded")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        onBulkActions()
                    } label: {
                        Label("Bulk actions", systemImage: "trash.badge.plus")
                            .font(.footnote.weight(.medium))
                    }

                    if hasMoreThreads {
                        Button(isLoading ? "Loading…" : "Load more") {
                            onLoadMore()
                        }
                        .font(.footnote.weight(.medium))
                        .disabled(isLoading)
                    }

                    Spacer()

                    Text("← Trash   Read →")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                ZStack {
                    ForEach(Array(threads.prefix(3).enumerated().reversed()), id: \.element.id) { index, thread in
                        GmailCardView(
                            thread: thread,
                            onOpened: { onOpened(thread) },
                            onSwiped: { direction in onSwiped(thread, direction) }
                        )
                        .frame(
                            width: min(geometry.size.width - 32, 430),
                            height: min(geometry.size.height - 100, 580)
                        )
                        .zIndex(Double(threads.count - index))
                        .allowsHitTesting(index == 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)


            }
        }
    }
}

#Preview {
    GmailModeView(viewModel: GmailViewModel())
}
