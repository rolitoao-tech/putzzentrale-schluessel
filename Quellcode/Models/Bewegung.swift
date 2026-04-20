import SwiftUI

enum BewegungGrund: String, CaseIterable, Codable {
    case ferien       = "Ferien"
    case krankheit    = "Krankheit"
    case einzelTermin = "Einzel-Termin"
}

enum BewegungStatus {
    case offen, ueberfaellig, zurueck

    var bezeichnung: String {
        switch self {
        case .offen:        return "Offen"
        case .ueberfaellig: return "Überfällig"
        case .zurueck:      return "Zurück"
        }
    }
    var farbe: Color {
        switch self {
        case .offen:        return .blue
        case .ueberfaellig: return .red
        case .zurueck:      return .green
        }
    }
    var icon: String {
        switch self {
        case .offen:        return "clock"
        case .ueberfaellig: return "exclamationmark.triangle.fill"
        case .zurueck:      return "checkmark.circle.fill"
        }
    }
}

struct Bewegung: Identifiable, Hashable {
    var id: Int64 = 0
    var kundenId: Int64 = 0
    var datumAbgang: Date = Date()          // Datum Einfordern
    var grund: BewegungGrund = .einzelTermin
    var stellvertretungRKId: Int64? = nil   // nil = im Büro, sonst Stellvertretungs-RK
    var erwarteteRueckgabe: Date? = nil     // Erwartete Rückgabe an zugeteilte RK
    var datumRueckgabe: Date? = nil         // Tatsächliche Rückgabe an zugeteilte RK
    var poolEingetragen: Bool = false
    var notizen: String = ""

    var status: BewegungStatus {
        if datumRueckgabe != nil { return .zurueck }
        guard let erwartet = erwarteteRueckgabe else { return .offen }
        let heute = Calendar.current.startOfDay(for: Date())
        let faellig = Calendar.current.startOfDay(for: erwartet)
        return heute > faellig ? .ueberfaellig : .offen
    }

    var istOffen: Bool { datumRueckgabe == nil }
}
