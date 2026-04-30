import SwiftUI

// Büro-Ablage eines eingeforderten Schlüssels
enum BueroAblage: String, CaseIterable, Codable {
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
    var id: UUID = UUID()
    var kundenId: UUID = UUID()
    var datumAbgang: Date = Date()
    var grund: BewegungGrund = .einzelTermin
    var stellvertretungRKId: UUID? = nil
    var bueroAblage: BueroAblage? = nil
    var bueroAblageDetail: String = ""
    var erwarteteRueckgabe: Date? = nil
    var datumRueckgabe: Date? = nil
    var poolEingetragen: Bool = false
    var notizen: String = ""
    // Vertragsende-Marker (W4/W5): Schlüssel ging endgültig an den Kunde
    var endgueltigeUebergabeAnKunde: Bool = false
    // Audit-Felder Erstellung (nie überschrieben)
    var erstelltVon: String = ""
    var erstelltAm: Date? = nil
    // Audit-Felder Modifikation (jede Änderung)
    var modifiziertVon: String = ""
    var modifiziertAm: Date? = nil
    // Storno-Felder (W10)
    var storniert: Bool = false
    var stornoBegruendung: String? = nil
    var storniertAm: Date? = nil
    var storniertVon: String? = nil
    // Prüfbedürftig-Marker (gesetzt durch W11-Cascade)
    var pruefbeduerftig: Bool = false
    var pruefbeduerftigGrund: String? = nil
    var pruefbeduerftigAm: Date? = nil

    var status: BewegungStatus {
        if datumRueckgabe != nil { return .zurueck }
        guard let erwartet = erwarteteRueckgabe else { return .offen }
        let heute = Calendar.current.startOfDay(for: Date())
        let faellig = Calendar.current.startOfDay(for: erwartet)
        return heute > faellig ? .ueberfaellig : .offen
    }

    var istOffen: Bool { datumRueckgabe == nil && !storniert }

    // Markiert als prüfbedürftig und noch offen
    var pruefbeduerftigOffen: Bool { pruefbeduerftig && istOffen }

    // Lesbarer Aufenthaltsort
    var aufenthaltsText: String {
        if let ablage = bueroAblage {
            switch ablage {
            case .safe:
                return bueroAblageDetail.isEmpty ? "Safe" : "Safe (Haken \(bueroAblageDetail))"
            case .dossier:
                return bueroAblageDetail.isEmpty ? "Dossier" : "Dossier (\(bueroAblageDetail))"
            }
        }
        return "Im Büro"
    }
}
