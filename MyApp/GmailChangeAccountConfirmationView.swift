import SwiftUI

public struct GmailChangeAccountConfirmationView: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    public init(
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.arrow.right")
                .font(.system(size: 42))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Change Gmail account?")
                    .font(.title3.weight(.semibold))

                Text("Swipey will sign out of this Gmail account on this device. Your Gmail messages will not be deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button("Change account", role: .destructive) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
    }
}
