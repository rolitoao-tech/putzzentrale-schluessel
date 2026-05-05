import Foundation

struct Kunde: Identifiable, Hashable {
    var id: UUID = UUID()
    var kundennummer: String = ""
    var name: String = ""
    var firma: String = ""
    var strasse: String = ""
    var plz: String = ""
    var wohnort: String = ""
    var telefon: String = ""
    var mobil: String = ""
    var email: String = ""
    var auftragsnummer: String = ""
    var zugeteilteReinigungskraftId: UUID? = nil
    var aktiv: Bool = true
    var notizen: String = ""
}
