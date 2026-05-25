import UIKit

@MainActor
protocol RemoteHapticsProviding {
    func impact()
}

final class UIKitRemoteHaptics: RemoteHapticsProviding {
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    init() {
        generator.prepare()
    }

    func impact() {
        generator.impactOccurred(intensity: 1)
        generator.prepare()
    }
}

struct NoOpRemoteHaptics: RemoteHapticsProviding {
    func impact() {
    }
}
