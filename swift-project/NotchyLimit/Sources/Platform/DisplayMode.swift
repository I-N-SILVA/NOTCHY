import Foundation

/// Where Notchy renders its usage UI.
public enum DisplayMode: String, Codable, CaseIterable {
    case auto       // notch if hardware notch detected, menubar otherwise
    case notch      // notch pill only (requires hardware notch)
    case menubar    // menubar status item only
    case both       // both simultaneously

    public var displayName: String {
        switch self {
        case .auto:    return "Auto"
        case .notch:   return "Notch"
        case .menubar: return "Menu Bar"
        case .both:    return "Both"
        }
    }

    /// The effective resolved mode — replaces .auto with the real choice.
    public static func resolved() -> DisplayMode {
        return NotchDetector.hasHardwareNotch() ? .notch : .menubar
    }

    public func shouldShowNotch() -> Bool {
        switch self {
        case .notch: return true
        case .both:  return true
        case .auto:  return NotchDetector.hasHardwareNotch()
        case .menubar: return false
        }
    }

    public func shouldShowMenuBar() -> Bool {
        switch self {
        case .menubar: return true
        case .both:    return true
        case .auto:    return !NotchDetector.hasHardwareNotch()
        case .notch:   return false
        }
    }
}
