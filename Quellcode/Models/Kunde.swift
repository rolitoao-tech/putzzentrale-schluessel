import SwiftUI

struct Kunde: Identifiable, Hashable {
    var id: Int64 = 0
    var kundennummer: String = ""
    var name: String = ""
    var wohnort: String = ""
    var zugeteilteReinigungskraftId: Int64 = 0  // 0 = keine Zuteilung
    var aktiv: Bool = true
    var notizen: String = ""
}
