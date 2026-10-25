import SwiftUI

public enum GmailBulkAction: Identifiable {
    case sender
    case unread

    public var id: String {
        switch self {
        case .sender:
            return "sender"
        case .unread:
            return "unread"
        }
    }
}

public struct GmailBulkActionSheet: View {
    let visibleThreads: [GmailThread]
    let filter: GmailFilter
    let onTrash: ([GmailThread]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: GmailBulkAction?
    @State private var isProcessing = false

    public init(
        visibleThreads: [GmailThread],
        filter: GmailFilter,
        onTrash: @escaping ([GmailThread]) async -> Void
    ) {
        self.visibleThreads = visibleThreads
        self.filter = filter
        self.onTrash = onTrash
    }

    private var unreadThreads: [GmailThread] {
        visibleThreads.filter(\.isUnread)
    }

    private var senderTitle: String {
        let query = filter.senderQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? "matching" : query
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let pendingAction {
                    GmailBulkConfirmationView(
                        actionTitle: confirmationTitle(for: pendingAction),
                        count: targetThreads(for: pendingAction).count,
                        isProcessing: isProcessing,
                        onCancel: {
                            self.pendingAction = nil
                        },
                        onConfirm: {
                            isProcessing = true
                            Task {
                                await onTrash(targetThreads(for: pendingAction))
                                dismiss()
                            }
                        }
                    )
                } else {
                    actionList
                }
            }
            .navigationTitle("Bulk actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    private var actionList: some View {
        List {
            Section {
                Text("Only conversations currently visible under your active filters will be affected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !filter.senderQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Sender") {
                    bulkActionButton(
                        title: "Trash visible " + senderTitle + " conversations",
                        subtitle: String(visibleThreads.count) + " conversation" + (visibleThreads.count == 1 ? "" : "s"),
                        action: .sender,
                        isDisabled: visibleThreads.isEmpty
                    )
                }
            }

            Section("Unread") {
                bulkActionButton(
                    title: "Trash visible unread conversations",
                    subtitle: String(unreadThreads.count) + " conversation" + (unreadThreads.count == 1 ? "" : "s"),
                    action: .unread,
                    isDisabled: unreadThreads.isEmpty
                )
            }
        }
    }

    private func bulkActionButton(
        title: String,
        subtitle: String,
        action: GmailBulkAction,
        isDisabled: Bool
    ) -> some View {
        Button {
            pendingAction = action
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .disabled(isDisabled)
    }

    private func targetThreads(for action: GmailBulkAction) -> [GmailThread] {
        switch action {
        case .sender:
            return visibleThreads
        case .unread:
            return unreadThreads
        }
    }

    private func confirmationTitle(for action: GmailBulkAction) -> String {
        switch action {
        case .sender:
            return "Trash visible sender conversations?"
        case .unread:
            return "Trash visible unread conversations?"
        }
    }
}

private struct GmailBulkConfirmationView: View {
    let actionTitle: String
    let count: Int
    let isProcessing: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text(actionTitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(
                    String(count) + " conversation" + (count == 1 ? "" : "s") +
                    " will be moved to Trash. You will have 5 seconds to undo the entire batch."
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(isProcessing ? "Moving…" : "Move to Trash", role: .destructive) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(isProcessing)

                Button("Cancel") {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .disabled(isProcessing)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
