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

    // Bewegungen wo diese RK als Stellvertretung eingesetzt ist
    func bewegungen(fuerStellvertretung rkId: Int64, nurOffen: Bool = false) -> [Bewegung] {
        db.fetchBewegungen(stellvertretungRKId: rkId, nurOffen: nurOffen)
    }

    // Alle Kunden die dieser RK fest zugeteilt sind
    func zugeteilteKunden(rkId: Int64) -> [Kunde] {
        kunden.filter { $0.zugeteilteReinigungskraftId == rkId }
    }

    func zugeteilteReinigungskraft(kundenId: Int64) -> Reinigungskraft? {
        guard let k = kunde(id: kundenId), k.zugeteilteReinigungskraftId != 0
        else { return nil }
        return reinigungskraft(id: k.zugeteilteReinigungskraftId)
    }

    var ueberfaelligeBewegungen: [Bewegung] {
        offeneBewegungen.filter { $0.status == .ueberfaellig }
    }

    // Schlüssel im Umlauf = Kunden mit offener Bewegung (nicht bei zugeteilter RK)
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

    func schluesselEinfordern(_ b: Bewegung) async {
        db.insertBewegung(b)
        if let faellig = b.erwarteteRueckgabe {
            let kName = kundeName(id: b.kundenId)
            let rkName = zugeteilteReinigungskraft(kundenId: b.kundenId)?.name ?? "–"
            await erinnerungen.erstelleRueckgabeErinnerung(
                schluesselName: kName,
                putzfrauName: rkName,
                faelligAm: faellig
            )
        }
        ladeAlles()
    }

    // Abwärtskompatibilität für bestehende View-Aufrufe
    func abgangErfassen(_ b: Bewegung) async {
        await schluesselEinfordern(b)
    }

    func rueckgabeEintragen(bewegungId: Int64, datum: Date = Date()) {
        db.rueckgabeEintragen(bewegungId: bewegungId, datum: datum)
        ladeAlles()
    }

    // Alle Stellvertreter-Schlüssel einer RK zurückgeben
    func alleStellvertretungsSchluesselZurueck(vonRKId rkId: Int64) {
        let offene = db.fetchBewegungen(stellvertretungRKId: rkId, nurOffen: true)
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

    // Stellvertretung auf bestehender Bewegung setzen
    func stellvertretungSetzen(bewegungId: Int64, rkId: Int64?) {
        guard var b = offeneBewegungen.first(where: { $0.id == bewegungId }) else { return }
        b.stellvertretungRKId = rkId
        db.updateBewegung(b)
        ladeAlles()
    }
}
