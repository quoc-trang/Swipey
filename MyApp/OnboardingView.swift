import SwiftUI

public struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep: Int = 0

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private let steps: [(icon: String, color: Color, title: String, description: String)] = [
        (
            "hand.draw.fill",
            .green,
            "Swipe Right to Keep",
            "Effortlessly keep your favorite memories, family photos, and important documents. Kept photos stay in your library and won't be shown again."
        ),
        (
            "trash.circle.fill",
            .red,
            "Swipe Left to Delete",
            "Quickly mark duplicates, bad shots, screenshots, and large video files for deletion. Don't worry—nothing is deleted immediately."
        ),
        (
            "checkmark.shield.fill",
            .blue,
            "Zero Risk Safety Net",
            "Marked photos enter a review queue. You have full control to confirm before any deletion happens. Plus, deleted photos remain recoverable in 'Recently Deleted' for 30 days."
        )
    ]

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Progress Dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? steps[currentStep].color : Color.secondary.opacity(0.3))
                            .frame(width: index == currentStep ? 24 : 8, height: 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.top, 24)

                // TabView for swiping pages
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        stepPageView(step: steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom Buttons
                VStack(spacing: 12) {
                    Button {
                        if currentStep < steps.count - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
                            isPresented = false
                        }
                    } label: {
                        Text(currentStep == steps.count - 1 ? "Start Cleaning" : "Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(steps[currentStep].color)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: steps[currentStep].color.opacity(0.3), radius: 8, y: 4)
                    }

                    if currentStep < steps.count - 1 {
                        Button("Skip") {
                            UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
                            isPresented = false
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func stepPageView(step: (icon: String, color: Color, title: String, description: String)) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(step.color.opacity(0.12))
                    .frame(width: 150, height: 150)

                Image(systemName: step.icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(step.color)
            }

            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
