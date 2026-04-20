import SwiftUI

// Wo der Schlüssel im Büro aufbewahrt wird
enum StandortTyp: String, CaseIterable, Codable {
    case safe    = "safe"
    case dossier = "dossier"

    var bezeichnung: String {
        switch self {
        case .safe:    return "Safe"
        case .dossier: return "Dossier"
        }
    }
    var icon: String {
        switch self {
        case .safe:    return "lock.fill"
        case .dossier: return "folder.fill"
        }
    }
}

struct Kunde: Identifiable, Hashable {
    var id: Int64 = 0
    var kundennummer: String = ""
    var name: String = ""
    var wohnort: String = ""
    // Standort im Büro: Safe (Haken 1–48) oder Dossier (Kürzel)
    var standortTyp: StandortTyp = .safe
    var standortDetail: String = ""  // z.B. "12" oder "SSI"
    var aktiv: Bool = true
    var notizen: String = ""

    // Lesbarer Standort-Text
    var standortText: String {
        switch standortTyp {
        case .safe:
            return standortDetail.isEmpty ? "Safe" : "Safe, Haken \(standortDetail)"
        case .dossier:
            return standortDetail.isEmpty ? "Dossier" : "Dossier \(standortDetail)"
        }
    }
}
