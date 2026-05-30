import SwiftUI

struct StatusDot: View {
    var status: UsageStatus
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .shadow(color: status.color.opacity(0.6), radius: 4)
    }
}

// MARK: - Incident styling

extension IncidentLevel {
    /// Tint used for outage badges in the UI.
    var tint: Color {
        switch self {
        case .none:        return Theme.statusHealthy
        case .minor:       return Theme.statusWarning
        case .maintenance: return Theme.accentCool
        case .major, .critical: return Theme.statusCritical
        }
    }

    var glyph: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver.fill"
        default:           return "exclamationmark.triangle.fill"
        }
    }
}

/// One-line outage banner shown in the expanded panel / popover.
struct IncidentBanner: View {
    let providerName: String
    let incident: ServiceIncident

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: incident.level.glyph)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(incident.level.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(providerName) — \(incident.summary)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(incident.level.tint.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(incident.level.tint.opacity(0.30), lineWidth: 0.75))
        )
    }
}
