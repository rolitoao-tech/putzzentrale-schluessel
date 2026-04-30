import Foundation

// Ziel-Standort eines manuell gesetzten Schlüssels (W11 — Übersteuerung)
enum ManuellerStandortTyp: String, CaseIterable, Codable {
    case beiRK      = "beiRK"
    case imBuero    = "imBuero"
    case beiStellv  = "beiStellv"
    case beimKunde  = "beimKunde"
    case unbekannt  = "unbekannt"

    var bezeichnung: String {
        switch self {
        case .beiRK:     return "Bei zugeteilter RK"
        case .imBuero:   return "Im Büro"
        case .beiStellv: return "Bei Stellvertretung"
        case .beimKunde: return "Beim Kunde"
        case .unbekannt: return "Unbekannt"
        }
    }
}

struct Kunde: Identifiable, Hashable {
    var id: UUID = UUID()
    var kundennummer: String = ""
    var name: String = ""
    var wohnort: String = ""
    var zugeteilteReinigungskraftId: UUID? = nil
    var aktiv: Bool = true
    var notizen: String = ""
    // Vertragsende (W4/W5)
    var schluesselZurueckgegebenAm: Date? = nil
    var schluesselZurueckgegebenVon: String? = nil
    // Manuell gesetzter Standort (W11 — Trigger ist standortManuellAm ≠ nil)
    var standortManuellAm: Date? = nil
    var standortManuellVon: String? = nil
    var standortManuellNotiz: String? = nil
    var standortManuellTyp: ManuellerStandortTyp? = nil
    var standortManuellStellvRKId: UUID? = nil

    var hatManuellenStandort: Bool { standortManuellAm != nil }
}
