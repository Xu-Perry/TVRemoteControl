import SwiftUI

enum KeyboardAvoidance {
    static func visibleKeyboardOverlap(from notification: Notification, screenBounds: CGRect = UIScreen.main.bounds) -> CGFloat {
        let keyboardFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
        let keyboardFrame: CGRect?
        if let rect = keyboardFrameValue as? CGRect {
            keyboardFrame = rect
        } else if let value = keyboardFrameValue as? NSValue {
            keyboardFrame = value.cgRectValue
        } else {
            keyboardFrame = nil
        }

        guard let keyboardFrame else {
            return 0
        }

        return max(0, screenBounds.maxY - keyboardFrame.minY)
    }

    static func canvasOffset(for keyboardOverlap: CGFloat, scale: CGFloat) -> CGFloat {
        guard keyboardOverlap > 0, scale > 0 else {
            return 0
        }

        return keyboardOverlap / scale
    }

    static func animation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        return .easeOut(duration: duration)
    }
}
