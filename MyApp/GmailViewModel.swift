import Foundation
import Observation

private struct GmailUndoItem {
    let thread: GmailThread
    let index: Int
}

@MainActor
@Observable
public final class GmailViewModel {
    public var threads: [GmailThread] = []
    public var isConnected = false
    public var isLoading = false
    public var isLoadingDetail = false
    public var hasMoreThreads = true
    public var errorMessage: String?
    public var selectedThreadDetail: GmailThreadDetail?
    public var bulkActionProgress: String?
    public var undoMessage: String?

    private let authManager: GmailOAuthManager
    private let apiService: GmailAPIService
    private var nextPageToken: String?
    private var undoBatch: [GmailUndoItem] = []
    private var undoTask: Task<Void, Never>?

    public init() {
        let authManager = GmailOAuthManager()
        self.authManager = authManager
        self.apiService = GmailAPIService(authManager: authManager)
        self.isConnected = authManager.hasStoredCredentials
    }

    public func connect() async {
        errorMessage = nil
        do {
            try await authManager.signIn()
            isConnected = true
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func disconnect() {
        undoTask?.cancel()
        authManager.signOut()
        isConnected = false
        threads = []
        nextPageToken = nil
        hasMoreThreads = true
        selectedThreadDetail = nil
        bulkActionProgress = nil
        undoBatch = []
        undoMessage = nil
    }

    public func restoreIfNeeded() async {
        guard isConnected, threads.isEmpty, !isLoading else { return }
        await reload()
    }

    public func reload() async {
        guard isConnected, !isLoading else { return }

        threads = []
        nextPageToken = nil
        hasMoreThreads = true
        await loadMore()
    }

    public func loadMore() async {
        guard isConnected, !isLoading, hasMoreThreads else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiService.fetchInboxThreads(pageToken: nextPageToken)
            threads.append(contentsOf: result.threads)
            nextPageToken = result.nextPageToken
            hasMoreThreads = result.nextPageToken != nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func loadDetail(for thread: GmailThread) async {
        isLoadingDetail = true
        errorMessage = nil

        do {
            selectedThreadDetail = try await apiService.fetchThreadDetail(thread.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingDetail = false
    }

    public func markAsRead(_ thread: GmailThread) async {
        guard thread.isUnread else { return }

        do {
            try await apiService.markThreadAsRead(thread.id)
            updateThread(thread.id) { current in
                GmailThread(
                    id: current.id,
                    subject: current.subject,
                    sender: current.sender,
                    recipients: current.recipients,
                    date: current.date,
                    snippet: current.snippet,
                    isUnread: false,
                    hasAttachments: current.hasAttachments,
                    messageCount: current.messageCount
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func moveToTrash(_ thread: GmailThread) async {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }

        threads.remove(at: index)

        do {
            try await apiService.trashThread(thread.id)
        } catch {
            threads.insert(thread, at: min(index, threads.count))
            errorMessage = error.localizedDescription
        }
    }

    public func trashThreads(_ targetThreads: [GmailThread]) async {
        let targetIDs = Set(targetThreads.map { $0.id })
        let undoItems = threads.enumerated()
            .filter { targetIDs.contains($0.element.id) }
            .map { GmailUndoItem(thread: $0.element, index: $0.offset) }

        guard !undoItems.isEmpty else { return }

        undoTask?.cancel()
        undoBatch = []
        undoMessage = nil
        threads.removeAll { targetIDs.contains($0.id) }

        var succeeded: [GmailUndoItem] = []
        var failed: [GmailUndoItem] = []

        for (index, item) in undoItems.enumerated() {
            bulkActionProgress = "Moving " + String(index + 1) + " of " + String(undoItems.count) + "…"

            do {
                try await apiService.trashThread(item.thread.id)
                succeeded.append(item)
            } catch {
                failed.append(item)
            }
        }

        bulkActionProgress = nil
        undoBatch = succeeded

        for item in failed.sorted(by: { $0.index < $1.index }) {
            threads.insert(item.thread, at: min(item.index, threads.count))
        }

        if !succeeded.isEmpty {
            let suffix = succeeded.count == 1 ? "" : "s"
            undoMessage = "Moved " + String(succeeded.count) + " conversation" + suffix + " to Trash"
            scheduleUndoExpiration()
        }

        if !failed.isEmpty {
            let suffix = failed.count == 1 ? "" : "s"
            errorMessage = String(failed.count) + " conversation" + suffix + " could not be moved to Trash."
        }
    }

    public func undoTrashBatch() async {
        guard !undoBatch.isEmpty else { return }

        undoTask?.cancel()
        let batch = undoBatch
        undoBatch = []
        undoMessage = nil

        var restored: [GmailUndoItem] = []
        var failed: [GmailUndoItem] = []

        for (index, item) in batch.enumerated() {
            bulkActionProgress = "Restoring " + String(index + 1) + " of " + String(batch.count) + "…"

            do {
                try await apiService.untrashThread(item.thread.id)
                restored.append(item)
            } catch {
                failed.append(item)
            }
        }

        for item in restored.sorted(by: { $0.index < $1.index }) {
            guard !threads.contains(where: { $0.id == item.thread.id }) else { continue }
            threads.insert(item.thread, at: min(item.index, threads.count))
        }

        bulkActionProgress = nil

        if !failed.isEmpty {
            let suffix = failed.count == 1 ? "" : "s"
            errorMessage = String(failed.count) + " conversation" + suffix + " could not be restored."
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    private func scheduleUndoExpiration() {
        undoTask?.cancel()
        undoTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.undoBatch = []
            self?.undoMessage = nil
        }
    }

    public func loadMockData() {
        let now = Date()
        threads = [
            GmailThread(
                id: "mock-thread-1",
                subject: "Your weekly product update",
                sender: "Product Team <updates@example.com>",
                recipients: "me",
                date: now.addingTimeInterval(-3_600),
                snippet: "Here are the highlights from this week...",
                isUnread: true,
                hasAttachments: false,
                messageCount: 1
            ),
            GmailThread(
                id: "mock-thread-2",
                subject: "Receipt for your recent order",
                sender: "Shop <orders@example.com>",
                recipients: "me",
                date: now.addingTimeInterval(-86_400),
                snippet: "Thanks for your purchase. Your receipt is attached.",
                isUnread: false,
                hasAttachments: true,
                messageCount: 2
            )
        ]
        isConnected = true
        isLoading = false
        hasMoreThreads = false
    }

    private func updateThread(_ id: String, update: (GmailThread) -> GmailThread) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[index] = update(threads[index])
    }

}
