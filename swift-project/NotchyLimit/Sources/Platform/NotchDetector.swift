import Foundation
import AppKit

/// Heuristic check for a hardware notch. macOS exposes
/// `NSScreen.safeAreaInsets.top > 0` on MacBooks with a notch.
enum NotchDetector {
    static func hasHardwareNotch() -> Bool {
        if #available(macOS 12.0, *) {
            return NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
        }
        return false
    }
}
