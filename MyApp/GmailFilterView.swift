import SwiftUI

public enum GmailSenderMatch: String, CaseIterable, Identifiable {
    case contains
    case exact

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .contains:
            return "Contains"
        case .exact:
            return "Exact"
        }
    }
}

public enum GmailReadFilter: String, CaseIterable, Identifiable {
    case all
    case unread
    case read

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .unread:
            return "Unread"
        case .read:
            return "Read"
        }
    }
}

public struct GmailFilter: Equatable {
    public var readFilter: GmailReadFilter = .all
    public var withAttachments = false
    public var senderQuery = ""
    public var senderMatch: GmailSenderMatch = .contains

    public init() {}

    public var isActive: Bool {
        readFilter != .all || withAttachments || !senderQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    public func matches(_ thread: GmailThread) -> Bool {
        switch readFilter {
        case .all:
            break
        case .unread where !thread.isUnread:
            return false
        case .read where thread.isUnread:
            return false
        default:
            break
        }

        if withAttachments && !thread.hasAttachments {
            return false
        }

        let keywords = senderQuery
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if !keywords.isEmpty {
            let sender = thread.sender.lowercased()
            let displayName = sender
                .split(separator: "<", maxSplits: 1, omittingEmptySubsequences: true)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? sender
            let email = sender
                .split(separator: "<", maxSplits: 1, omittingEmptySubsequences: true)
                .dropFirst()
                .first?
                .replacingOccurrences(of: ">", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? sender

            let matches = keywords.contains { keyword in
                switch senderMatch {
                case .contains:
                    return sender.contains(keyword)
                case .exact:
                    return displayName == keyword || email == keyword
                }
            }

            guard matches else {
                return false
            }
        }

        return true
    }
}

public struct GmailFilterSheet: View {
    @Binding private var filter: GmailFilter
    @Environment(\.dismiss) private var dismiss

    public init(filter: Binding<GmailFilter>) {
        _filter = filter
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Message status") {
                    Picker("Show", selection: $filter.readFilter) {
                        ForEach(GmailReadFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Sender") {
                    TextField("e.g. linkedin, facebook", text: $filter.senderQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Match", selection: $filter.senderMatch) {
                        ForEach(GmailSenderMatch.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Separate multiple sender names with commas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        senderPreset("LinkedIn", value: "linkedin")
                        senderPreset("Facebook", value: "facebook")
                        senderPreset("Social", value: "linkedin,facebook,instagram,twitter")
                    }
                }

                Section {
                    Toggle("With attachments", isOn: $filter.withAttachments)
                }

                Section {
                    Button("Clear filters") {
                        filter = GmailFilter()
                    }
                    .disabled(!filter.isActive)
                }
            }
            .navigationTitle("Filter Gmail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func senderPreset(_ title: String, value: String) -> some View {
        Button(title) {
            filter.senderQuery = value
        }
        .font(.caption.weight(.medium))
        .buttonStyle(.bordered)
    }
}
