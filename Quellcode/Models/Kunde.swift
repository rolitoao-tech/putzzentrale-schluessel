import Foundation

struct Kunde: Identifiable, Hashable {
    var id: UUID = UUID()
    var kundennummer: String = ""
    var name: String = ""
    var wohnort: String = ""
    var zugeteilteReinigungskraftId: UUID? = nil
    var aktiv: Bool = true
    var notizen: String = ""
}
