import SwiftUI

enum KundeStatus: String, CaseIterable, Codable {
    case aktiv = "aktiv"
    case inaktiv = "inaktiv"

    var bezeichnung: String {
        switch self {
        case .aktiv:   return "Aktiv"
        case .inaktiv: return "Inaktiv"
        }
    }

    var farbe: Color {
        switch self {
        case .aktiv:   return .green
        case .inaktiv: return .secondary
        }
    }
}

struct Kunde: Identifiable, Hashable {
    var id: Int64 = 0
    var name: String = ""
    var adresse: String = ""
    var objekt: String = ""
    var status: KundeStatus = .aktiv
    var notizen: String = ""
}
