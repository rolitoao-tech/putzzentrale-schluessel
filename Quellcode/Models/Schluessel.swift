import Foundation

struct Schluessel: Identifiable, Hashable {
    var id: Int64 = 0
    var bezeichnung: String = ""
    var kundeId: Int64 = 0
    var anzahlKopien: Int = 1
    var notizen: String = ""
    var verloren: Bool = false
}
