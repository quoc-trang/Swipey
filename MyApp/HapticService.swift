import UIKit

/// Manages tactile feedback throughout the app, with respect to user settings.
public final class HapticService {
    public static let shared = HapticService()

    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    public var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "haptics_enabled")
        }
    }

    public init() {
        impactMedium.prepare()
        impactLight.prepare()
    }

    public func prepare() {
        guard isEnabled else { return }
        impactMedium.prepare()
        impactLight.prepare()
    }

    public func swipeDelete() {
        guard isEnabled else { return }
        impactRigid.impactOccurred()
    }

    public func swipeKeep() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    public func tap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    public func deletionCompleted() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    public func undo() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }
}
