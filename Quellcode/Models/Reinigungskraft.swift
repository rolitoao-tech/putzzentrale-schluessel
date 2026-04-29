import Foundation

struct Reinigungskraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var aktiv: Bool = true
    var notizen: String = ""
}
