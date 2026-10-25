import SwiftUI

public struct SettingsView: View {
    @Bindable var viewModel: SwipeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var hapticsEnabled: Bool = HapticService.shared.isEnabled
    @State private var soundEnabled: Bool = UserDefaults.standard.object(forKey: "sound_enabled") as? Bool ?? true
    @State private var showResetConfirm: Bool = false
    @State private var showOnboardingAgain: Bool = false
    @State private var showPrivacySheet: Bool = false

    private let stats = StatsManager.shared

    public init(viewModel: SwipeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                // Cleaning Statistics Section
                Section("Your Cleaning Stats") {
                    HStack(spacing: 16) {
                        StatBox(
                            title: "Deleted",
                            value: "\(stats.totalDeletedCount)",
                            icon: "trash.fill",
                            color: .red
                        )

                        StatBox(
                            title: "Freed",
                            value: stats.formattedStorageSaved,
                            icon: "arrow.down.to.line.compact",
                            color: .blue
                        )

                        StatBox(
                            title: "Streak",
                            value: "\(stats.streakDays)d",
                            icon: "flame.fill",
                            color: .orange
                        )
                    }
                    .padding(.vertical, 6)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // App Feedback & Toggles
                Section("Feedback & Controls") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .onChange(of: hapticsEnabled) { _, newValue in
                        HapticService.shared.isEnabled = newValue
                    }

                    Toggle(isOn: $soundEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    .onChange(of: soundEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "sound_enabled")
                    }
                }

                // Library Maintenance
                Section("Photo Queue") {
                    HStack {
                        Label("Photos Already Kept", systemImage: "archivebox.fill")
                        Spacer()
                        Text("\(viewModel.kept.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Kept Photos History", systemImage: "arrow.counterclockwise")
                    }
                }

                // Help & Safety Net
                Section("Safety & Guidance") {
                    Button {
                        showOnboardingAgain = true
                    } label: {
                        Label("How Swipey Works", systemImage: "questionmark.circle.fill")
                            .foregroundStyle(Color.primary)
                    }

                    Button {
                        showPrivacySheet = true
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                            .foregroundStyle(Color.primary)
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (Build 1)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .confirmationDialog(
                "Reset Kept Photos?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Kept History", role: .destructive) {
                    viewModel.resetKeptHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This allows photos you previously kept to reappear in your swipe feed. No photos will be deleted.")
            }
            .sheet(isPresented: $showOnboardingAgain) {
                OnboardingView(isPresented: $showOnboardingAgain)
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyPolicyView()
            }
        }
    }
}

// MARK: - Stat Box
private struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Privacy Policy View
public struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                            .padding(.top, 12)
                        Spacer()
                    }

                    Text("Your Photos Never Leave Your Device")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        PolicyPoint(
                            icon: "cpu",
                            title: "100% On-Device Processing",
                            description: "Swipey processes all photos, thumbnails, and Vision analysis entirely on your iPhone or iPad. We do not operate servers or transmit any photos externally."
                        )

                        PolicyPoint(
                            icon: "eye.slash.fill",
                            title: "Zero Tracking & Analytics",
                            description: "No analytics SDKs, advertising trackers, or telemetry tools are installed. Your data remains exclusively yours."
                        )

                        PolicyPoint(
                            icon: "shield.lefthalf.filled",
                            title: "Apple Photos Native Safety Net",
                            description: "Swipey uses official Apple PhotoKit APIs. Photos marked for deletion are sent to Apple's system 'Recently Deleted' folder and are never permanently erased by Swipey."
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PolicyPoint: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SwipeViewModel(isMockMode: true))
}
