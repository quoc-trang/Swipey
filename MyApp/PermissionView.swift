import SwiftUI
import Photos

public struct PermissionView: View {
    @Bindable var photoService: PhotoLibraryService
    var onAuthorized: () -> Void = {}

    public init(photoService: PhotoLibraryService, onAuthorized: @escaping () -> Void = {}) {
        self.photoService = photoService
        self.onAuthorized = onAuthorized
    }

    public var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: iconName)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 12) {
                Text(titleText)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 14) {
                if photoService.authorizationStatus == .notDetermined {
                    Button {
                        Task {
                            let status = await photoService.requestAuthorization()
                            if status == .authorized || status == .limited {
                                onAuthorized()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "photo.stack")
                            Text("Allow Access to Photos")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if photoService.authorizationStatus == .denied || photoService.authorizationStatus == .restricted {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Open iOS Settings")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if photoService.authorizationStatus == .limited {
                    Button {
                        onAuthorized()
                    } label: {
                        Text("Continue with Selected Photos")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Grant Full Access in Settings")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding()
    }

    private var iconName: String {
        switch photoService.authorizationStatus {
        case .notDetermined:
            return "photo.on.rectangle.angled"
        case .denied, .restricted:
            return "lock.slash.fill"
        case .limited:
            return "photo.badge.checkmark"
        case .authorized:
            return "checkmark.circle.fill"
        @unknown default:
            return "photo"
        }
    }

    private var iconColor: Color {
        switch photoService.authorizationStatus {
        case .notDetermined:
            return .accentColor
        case .denied, .restricted:
            return .red
        case .limited:
            return .orange
        case .authorized:
            return .green
        @unknown default:
            return .accentColor
        }
    }

    private var titleText: String {
        switch photoService.authorizationStatus {
        case .notDetermined:
            return "Declutter Your Photo Library"
        case .denied, .restricted:
            return "Photo Access is Restricted"
        case .limited:
            return "Limited Access Enabled"
        case .authorized:
            return "Photos Connected"
        @unknown default:
            return "Swipey"
        }
    }

    private var subtitleText: String {
        switch photoService.authorizationStatus {
        case .notDetermined:
            return "Swipey needs read and write access to help you swipe through your photos, keep what matters, and batch-delete the rest."
        case .denied, .restricted:
            return "Swipey cannot view or delete photos without permission. Please go to Settings and enable Photos access for Swipey."
        case .limited:
            return "You have given Swipey access to some of your photos. You can continue with these, or grant Full Access in Settings for the best cleaning experience."
        case .authorized:
            return "Ready to start cleaning your photos."
        @unknown default:
            return ""
        }
    }
}

#Preview("Not Determined") {
    let service = PhotoLibraryService.shared
    service.authorizationStatus = .notDetermined
    return PermissionView(photoService: service)
}

#Preview("Denied") {
    let service = PhotoLibraryService.shared
    service.authorizationStatus = .denied
    return PermissionView(photoService: service)
}
