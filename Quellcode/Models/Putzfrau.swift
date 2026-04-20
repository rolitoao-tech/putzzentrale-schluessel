import SwiftUI

enum PutzfrauStatus: String, CaseIterable, Codable {
    case aktiv    = "aktiv"
    case krank    = "krank"
    case ferien   = "ferien"
    case inaktiv  = "inaktiv"

    var bezeichnung: String {
        switch self {
        case .aktiv:   return "Aktiv"
        case .krank:   return "Krank"
        case .ferien:  return "Ferien"
        case .inaktiv: return "Inaktiv"
        }
    }

    var farbe: Color {
        switch self {
        case .aktiv:   return .green
        case .krank:   return .orange
        case .ferien:  return .blue
        case .inaktiv: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .aktiv:   return "checkmark.circle.fill"
        case .krank:   return "cross.circle.fill"
        case .ferien:  return "sun.max.fill"
        case .inaktiv: return "minus.circle.fill"
        }
    }
}

struct Putzfrau: Identifiable, Hashable {
    var id: Int64 = 0
    var name: String = ""
    var telefon: String = ""
    var email: String = ""
    var status: PutzfrauStatus = .aktiv
    var notizen: String = ""
}
