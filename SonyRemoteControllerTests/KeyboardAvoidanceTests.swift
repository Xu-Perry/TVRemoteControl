import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import SonyRemoteController

struct KeyboardAvoidanceTests {
    @Test func visibleKeyboardOverlapTracksScreenCoveredByKeyboard() {
        let notification = Notification(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 500, width: 390, height: 344))
            ]
        )

        let overlap = KeyboardAvoidance.visibleKeyboardOverlap(
            from: notification,
            screenBounds: CGRect(x: 0, y: 0, width: 390, height: 844)
        )

        #expect(overlap == 344)
    }

    @Test func hiddenKeyboardProducesNoOverlap() {
        let notification = Notification(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 844, width: 390, height: 344))
            ]
        )

        let overlap = KeyboardAvoidance.visibleKeyboardOverlap(
            from: notification,
            screenBounds: CGRect(x: 0, y: 0, width: 390, height: 844)
        )

        #expect(overlap == 0)
    }

    @Test func canvasOffsetCompensatesForScaledDesignCanvas() {
        #expect(KeyboardAvoidance.canvasOffset(for: 344, scale: 0.8) == 430)
        #expect(KeyboardAvoidance.canvasOffset(for: 344, scale: 0) == 0)
        #expect(KeyboardAvoidance.canvasOffset(for: 0, scale: 0.8) == 0)
    }
}
