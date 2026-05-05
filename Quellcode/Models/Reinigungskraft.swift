import Foundation

struct Reinigungskraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var strasse: String = ""
    var plz: String = ""
    var ort: String = ""
    var telefon: String = ""
    var mobil: String = ""
    var aktiv: Bool = true
    var notizen: String = ""
}
