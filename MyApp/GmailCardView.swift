import SwiftUI

public struct GmailCardView: View {
    let thread: GmailThread
    var onOpened: () -> Void
    var onSwiped: (GmailSwipeDirection) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    private let swipeThreshold: CGFloat = 120

    public init(
        thread: GmailThread,
        onOpened: @escaping () -> Void,
        onSwiped: @escaping (GmailSwipeDirection) -> Void
    ) {
        self.thread = thread
        self.onOpened = onOpened
        self.onSwiped = onSwiped
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(thread.isUnread ? Color.blue : Color.secondary.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(senderInitial)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(thread.isUnread ? .white : .secondary)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.sender)
                                .font(.headline)
                                .lineLimit(1)

                            if let date = thread.date {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if thread.isUnread {
                            Circle()
                                .fill(.blue)
                                .frame(width: 10, height: 10)
                                .accessibilityLabel("Unread")
                        }
                    }

                    Text(thread.subject)
                        .font(.title3.weight(.semibold))
                        .lineLimit(3)

                    Text(thread.snippet)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    HStack(spacing: 12) {
                        Label(
                            thread.messageCount == 1 ? "1 message" : "\(thread.messageCount) messages",
                            systemImage: "bubble.left.and.bubble.right"
                        )

                        if thread.hasAttachments {
                            Label("Attachment", systemImage: "paperclip")
                        }

                        Spacer()

                        Text("Tap to read")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(24)

                swipeOverlay
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(x: dragOffset.width, y: dragOffset.height * 0.35)
            .rotationEffect(.degrees(Double(dragOffset.width / 18)))
            .gesture(dragGesture(width: proxy.size.width))
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !isDragging else { return }
                    onOpened()
                }
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.72), value: dragOffset)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Tap to read. Swipe left to move to Trash. Swipe right to mark as read.")
        }
    }

    private var senderInitial: String {
        thread.sender
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
            .map(String.init)?
            .uppercased() ?? "?"
    }

    private var accessibilityDescription: String {
        let unread = thread.isUnread ? "Unread. " : ""
        return "\(unread)\(thread.sender), \(thread.subject). \(thread.snippet)"
    }

    private var swipeOverlay: some View {
        ZStack {
            if dragOffset.width < 0 {
                HStack {
                    Spacer()
                    Label("TRASH", systemImage: "trash.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.red)
                        .padding()
                }
            } else if dragOffset.width > 0 {
                HStack {
                    Label("MARK READ", systemImage: "envelope.open.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.blue)
                        .padding()
                    Spacer()
                }
            }
        }
        .opacity(min(Double(abs(dragOffset.width) / swipeThreshold), 1))
        .allowsHitTesting(false)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                dragOffset = gesture.translation
                isDragging = true
            }
            .onEnded { gesture in
                let translationX = gesture.translation.width

                if translationX < -swipeThreshold {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = CGSize(width: -width * 1.5, height: gesture.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwiped(.trash)
                    }
                } else if translationX > swipeThreshold {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = CGSize(width: width * 1.5, height: gesture.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwiped(.markRead)
                    }
                } else {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                        dragOffset = .zero
                    }
                }

                isDragging = false
            }
    }
}

public enum GmailSwipeDirection {
    case trash
    case markRead
}

#Preview {
    GmailCardView(
        thread: GmailThread(
            id: "preview",
            subject: "Your weekly update",
            sender: "Example <example@example.com>",
            recipients: "me",
            date: Date(),
            snippet: "This is a preview of an email conversation in Swipey.",
            isUnread: true,
            hasAttachments: true,
            messageCount: 2
        ),
        onOpened: {},
        onSwiped: { _ in }
    )
    .frame(height: 560)
    .padding()
}
