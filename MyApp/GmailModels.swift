import Foundation

public struct GmailThread: Identifiable, Hashable, Sendable {
    public let id: String
    public let subject: String
    public let sender: String
    public let recipients: String
    public let date: Date?
    public let snippet: String
    public let isUnread: Bool
    public let hasAttachments: Bool
    public let messageCount: Int

    public init(
        id: String,
        subject: String,
        sender: String,
        recipients: String,
        date: Date?,
        snippet: String,
        isUnread: Bool,
        hasAttachments: Bool,
        messageCount: Int
    ) {
        self.id = id
        self.subject = subject
        self.sender = sender
        self.recipients = recipients
        self.date = date
        self.snippet = snippet
        self.isUnread = isUnread
        self.hasAttachments = hasAttachments
        self.messageCount = messageCount
    }
}

public struct GmailMessageDetail: Identifiable, Hashable, Sendable {
    public let id: String
    public let sender: String
    public let recipients: String
    public let date: Date?
    public let body: String
    public let isUnread: Bool

    public init(
        id: String,
        sender: String,
        recipients: String,
        date: Date?,
        body: String,
        isUnread: Bool
    ) {
        self.id = id
        self.sender = sender
        self.recipients = recipients
        self.date = date
        self.body = body
        self.isUnread = isUnread
    }
}

public struct GmailThreadDetail: Identifiable, Hashable, Sendable {
    public let id: String
    public let subject: String
    public let messages: [GmailMessageDetail]

    public init(id: String, subject: String, messages: [GmailMessageDetail]) {
        self.id = id
        self.subject = subject
        self.messages = messages
    }
}

struct GmailThreadListResponse: Decodable {
    let threads: [GmailThreadReference]?
    let nextPageToken: String?
}

struct GmailThreadReference: Decodable {
    let id: String
    let snippet: String?
}

struct GmailThreadResponse: Decodable {
    let id: String
    let messages: [GmailMessageResponse]?
}

struct GmailMessageResponse: Decodable {
    let id: String
    let labelIds: [String]?
    let snippet: String?
    let internalDate: String?
    let payload: GmailPayload?
}

struct GmailPayload: Decodable {
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailBody: Decodable {
    let data: String?
}

struct GmailTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int?
    let refreshToken: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

@MainActor
enum GmailMIME {
    static func header(_ name: String, from headers: [GmailHeader]?) -> String {
        headers?.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value ?? ""
    }

    static func date(from message: GmailMessageResponse) -> Date? {
        if let milliseconds = message.internalDate, let value = Double(milliseconds) {
            return Date(timeIntervalSince1970: value / 1000)
        }

        let dateString = header("Date", from: message.payload?.headers)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }

    static func bodyText(from payload: GmailPayload?) -> String {
        guard let payload else { return "" }

        if let parts = payload.parts, !parts.isEmpty {
            let plainText = parts
                .filter { $0.mimeType == "text/plain" }
                .map(bodyText(from:))
                .first(where: { !$0.isEmpty })

            if let plainText {
                return plainText
            }

            if let html = parts
                .filter({ $0.mimeType == "text/html" })
                .map(bodyText(from:))
                .first(where: { !$0.isEmpty }) {
                return stripHTML(html)
            }

            return parts.map(bodyText(from:)).first(where: { !$0.isEmpty }) ?? ""
        }

        guard let encoded = payload.body?.data else { return "" }
        let decoded = decodeBase64URL(encoded) ?? ""
        return payload.mimeType == "text/html" ? stripHTML(decoded) : decoded
    }

    static func decodeBase64URL(_ value: String) -> String? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized += String(repeating: "=", count: (4 - normalized.count % 4) % 4)

        guard let data = Data(base64Encoded: normalized) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func stripHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<br\\s*/?>", with: "\\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\\n\\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
