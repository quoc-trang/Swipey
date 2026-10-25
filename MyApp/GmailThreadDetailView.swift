import SwiftUI

public struct GmailThreadDetailView: View {
    let thread: GmailThread
    let detail: GmailThreadDetail?
    let isLoading: Bool
    var onDismiss: () -> Void

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading && detail == nil {
                    ProgressView("Loading conversation…")
                } else if let detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(detail.subject)
                                .font(.title2.weight(.bold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(detail.messages) { message in
                                GmailMessageView(message: message)
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Swipey could not load this conversation.")
                    )
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

private struct GmailMessageView: View {
    let message: GmailMessageDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.sender)
                        .font(.headline)
                    if !message.recipients.isEmpty {
                        Text("To: \(message.recipients)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let date = message.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text(message.body.isEmpty ? "No readable message content." : message.body)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
