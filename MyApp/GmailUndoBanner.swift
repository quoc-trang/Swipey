import SwiftUI

public struct GmailUndoBanner: View {
    let message: String
    let onUndo: () -> Void

    public init(message: String, onUndo: @escaping () -> Void) {
        self.message = message
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .fontWeight(.bold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}
