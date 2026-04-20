import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    @Published var kunden: [Kunde] = []
    @Published var reinigungskraefte: [Reinigungskraft] = []
    @Published var offeneBewegungen: [Bewegung] = []

    let erinnerungen = ErinnerungsService()
    private let db = DatabaseManager.shared

    init() {
        ladeAlles()
        Task { await erinnerungen.zugriffAnfordern() }
    }

    // MARK: - Laden

    func ladeAlles() {
        kunden               = db.fetchKunden()
        reinigungskraefte    = db.fetchReinigungskraefte()
        offeneBewegungen     = db.fetchOffeneBewegungen()
    }

    // MARK: - Lookup

    func kunde(id: Int64) -> Kunde? { kunden.first { $0.id == id } }
    func reinigungskraft(id: Int64) -> Reinigungskraft? { reinigungskraefte.first { $0.id == id } }

    func kundeName(id: Int64) -> String { kunde(id: id)?.name ?? "–" }
    func rkName(id: Int64) -> String { reinigungskraft(id: id)?.name ?? "–" }

    func aktiveBewegung(kundenId: Int64) -> Bewegung? {
        db.fetchAktiveBewegung(kundenId: kundenId)
    }

    func bewegungen(fuerKunde kid: Int64) -> [Bewegung] {
        db.fetchBewegungen(kundenId: kid)
    }

    func bewegungen(fuerRK rkId: Int64, nurOffen: Bool = false) -> [Bewegung] {
        db.fetchBewegungen(reinigungskraftId: rkId, nurOffen: nurOffen)
    }

    // Schlüssel aktuell bei welcher Reinigungskraft?
    func aktuelleReinigungskraft(kundenId: Int64) -> Reinigungskraft? {
        guard let b = aktiveBewegung(kundenId: kundenId) else { return nil }
        return reinigungskraft(id: b.reinigungskraftId)
    }

    var ueberfaelligeBewegungen: [Bewegung] {
        offeneBewegungen.filter { $0.status == .ueberfaellig }
    }

    var schluesselImUmlauf: Int {
        Set(offeneBewegungen.map(\.kundenId)).count
    }

    // MARK: - Kunden CRUD

    func kundeHinzufuegen(_ k: Kunde) {
        var neu = k; neu.id = db.insertKunde(k)
        kunden.append(neu)
        kunden.sort { $0.name < $1.name }
    }

    func kundeAktualisieren(_ k: Kunde) {
        db.updateKunde(k)
        if let i = kunden.firstIndex(where: { $0.id == k.id }) { kunden[i] = k }
    }

    func kundeLoeschen(id: Int64) {
        db.deleteKunde(id: id)
        kunden.removeAll { $0.id == id }
    }

    // Standort im Büro aktualisieren (nach Rückgabe)
    func standortAktualisieren(kundenId: Int64, typ: StandortTyp, detail: String) {
        guard var k = kunde(id: kundenId) else { return }
        k.standortTyp = typ; k.standortDetail = detail
        kundeAktualisieren(k)
    }

    // MARK: - Reinigungskräfte CRUD

    func rkHinzufuegen(_ r: Reinigungskraft) {
        var neu = r; neu.id = db.insertReinigungskraft(r)
        reinigungskraefte.append(neu)
        reinigungskraefte.sort { $0.name < $1.name }
    }

    func rkAktualisieren(_ r: Reinigungskraft) {
        db.updateReinigungskraft(r)
        if let i = reinigungskraefte.firstIndex(where: { $0.id == r.id }) { reinigungskraefte[i] = r }
    }

    func rkLoeschen(id: Int64) {
        db.deleteReinigungskraft(id: id)
        reinigungskraefte.removeAll { $0.id == id }
    }

    // MARK: - Bewegungen

    func abgangErfassen(_ b: Bewegung) async {
        db.insertBewegung(b)
        if let faellig = b.erwarteteRueckgabe {
            let kName = kundeName(id: b.kundenId)
            let rName = rkName(id: b.reinigungskraftId)
            await erinnerungen.erstelleRueckgabeErinnerung(
                schluesselName: kName,
                putzfrauName: rName,
                faelligAm: faellig
            )
        }
        ladeAlles()
    }

    func rueckgabeEintragen(bewegungId: Int64, datum: Date = Date()) {
        db.rueckgabeEintragen(bewegungId: bewegungId, datum: datum)
        ladeAlles()
    }

    func alleSchluesselZurueck(vonRKId rkId: Int64) {
        let offene = db.fetchBewegungen(reinigungskraftId: rkId, nurOffen: true)
        for b in offene { db.rueckgabeEintragen(bewegungId: b.id) }
        ladeAlles()
    }

    func bewegungAktualisieren(_ b: Bewegung) {
        db.updateBewegung(b)
        ladeAlles()
    }

    func bewegungLoeschen(id: Int64) {
        db.deleteBewegung(id: id)
        ladeAlles()
    }
}
