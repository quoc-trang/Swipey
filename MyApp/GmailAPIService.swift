import Foundation

public enum GmailAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(statusCode: Int)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Gmail returned an invalid response."
        case .unauthorized:
            return "Gmail authorization has expired. Please connect again."
        case let .server(statusCode):
            return "Gmail returned an error (\(statusCode))."
        case .decodingFailed:
            return "Swipey could not read the Gmail response."
        }
    }
}

@MainActor
public final class GmailAPIService {
    private let authManager: GmailOAuthManager
    private let session: URLSession
    private let baseURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!

    public init(authManager: GmailOAuthManager, session: URLSession = .shared) {
        self.authManager = authManager
        self.session = session
    }

    public func fetchInboxThreads(
        pageToken: String? = nil,
        maxResults: Int = 50
    ) async throws -> (threads: [GmailThread], nextPageToken: String?) {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("threads"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "labelIds", value: "INBOX"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        if let pageToken {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let listResponse: GmailThreadListResponse = try await request(url: components.url!)
        let references = listResponse.threads ?? []

        let threads = try await withThrowingTaskGroup(
            of: GmailThread?.self,
            returning: [GmailThread].self
        ) { group in
            for reference in references {
                group.addTask { [self] in
                    let response: GmailThreadResponse = try await request(
                        url: baseURL.appendingPathComponent("threads/\(reference.id)")
                            .appending(queryItems: [
                                URLQueryItem(name: "format", value: "metadata"),
                                URLQueryItem(name: "metadataHeaders", value: "From"),
                                URLQueryItem(name: "metadataHeaders", value: "To"),
                                URLQueryItem(name: "metadataHeaders", value: "Subject"),
                                URLQueryItem(name: "metadataHeaders", value: "Date")
                            ])
                    )
                    return await MainActor.run {
                        makeThread(from: response, fallbackSnippet: reference.snippet ?? "")
                    }
                }
            }

            var results: [GmailThread] = []
            results.reserveCapacity(references.count)
            for try await thread in group {
                if let thread {
                    results.append(thread)
                }
            }
            return results.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }

        return (threads, listResponse.nextPageToken)
    }

    public func fetchThreadDetail(_ threadID: String) async throws -> GmailThreadDetail {
        let response: GmailThreadResponse = try await request(
            url: baseURL.appendingPathComponent("threads/\(threadID)")
                .appending(queryItems: [URLQueryItem(name: "format", value: "full")])
        )

        let messages = (response.messages ?? []).map { message in
            GmailMessageDetail(
                id: message.id,
                sender: GmailMIME.header("From", from: message.payload?.headers),
                recipients: GmailMIME.header("To", from: message.payload?.headers),
                date: GmailMIME.date(from: message),
                body: GmailMIME.bodyText(from: message.payload),
                isUnread: message.labelIds?.contains("UNREAD") == true
            )
        }

        let subject = response.messages?
            .compactMap { GmailMIME.header("Subject", from: $0.payload?.headers).nilIfEmpty }
            .first ?? "Conversation"

        return GmailThreadDetail(id: response.id, subject: subject, messages: messages)
    }

    public func markThreadAsRead(_ threadID: String) async throws {
        try await modifyThread(threadID, body: ["removeLabelIds": ["UNREAD"]])
    }

    public func trashThread(_ threadID: String) async throws {
        try await requestVoid(
            url: baseURL.appendingPathComponent("threads/\(threadID)/trash"),
            method: "POST"
        )
    }

    public func untrashThread(_ threadID: String) async throws {
        try await requestVoid(
            url: baseURL.appendingPathComponent("threads/\(threadID)/untrash"),
            method: "POST"
        )
    }

    private func modifyThread(_ threadID: String, body: [String: [String]]) async throws {
        let url = baseURL.appendingPathComponent("threads/\(threadID)/modify")
        var request = try await authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let request = try await authorizedRequest(url: url)
        let (data, response) = try await session.data(for: request)
        try validate(response)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GmailAPIError.decodingFailed
        }
    }

    private func requestVoid(url: URL, method: String) async throws {
        var request = try await authorizedRequest(url: url)
        request.httpMethod = method
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        let token = try await authManager.validAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw GmailAPIError.unauthorized
        default:
            throw GmailAPIError.server(statusCode: httpResponse.statusCode)
        }
    }

    private func makeThread(
        from response: GmailThreadResponse,
        fallbackSnippet: String
    ) -> GmailThread? {
        guard let messages = response.messages, !messages.isEmpty else { return nil }

        let latestMessage = messages.last!
        let subject = messages
            .reversed()
            .compactMap { GmailMIME.header("Subject", from: $0.payload?.headers).nilIfEmpty }
            .first ?? "No subject"

        let sender = GmailMIME.header("From", from: latestMessage.payload?.headers)
        let recipients = GmailMIME.header("To", from: latestMessage.payload?.headers)
        let snippet = latestMessage.snippet?.nilIfEmpty ?? fallbackSnippet
        let isUnread = messages.contains { $0.labelIds?.contains("UNREAD") == true }
        let hasAttachments = messages.contains { message in
            containsAttachment(in: message.payload)
        }

        return GmailThread(
            id: response.id,
            subject: subject,
            sender: sender.isEmpty ? "Unknown sender" : sender,
            recipients: recipients,
            date: GmailMIME.date(from: latestMessage),
            snippet: snippet,
            isUnread: isUnread,
            hasAttachments: hasAttachments,
            messageCount: messages.count
        )
    }

    private func containsAttachment(in payload: GmailPayload?) -> Bool {
        guard let payload else { return false }
        if let filename = payload.filename, !filename.isEmpty {
            return true
        }
        return payload.parts?.contains { containsAttachment(in: $0) } == true
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return components.url!
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
