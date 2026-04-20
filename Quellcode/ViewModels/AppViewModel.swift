import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Stammdaten

    @Published var kunden: [Kunde] = []
    @Published var putzfrauen: [Putzfrau] = []
    @Published var schluessel: [Schluessel] = []
    @Published var offeneBewegungen: [Bewegung] = []

    let erinnerungen = ErinnerungsService()
    private let db = DatabaseManager.shared

    init() {
        ladeAlles()
        Task { await erinnerungen.zugriffAnfordern() }
    }

    // MARK: - Laden

    func ladeAlles() {
        kunden            = db.fetchKunden()
        putzfrauen        = db.fetchPutzfrauen()
        schluessel        = db.fetchSchluessel()
        offeneBewegungen  = db.fetchOffeneBewegungen()
    }

    // MARK: - Lookup-Helpers

    func kunde(id: Int64) -> Kunde? { kunden.first { $0.id == id } }
    func putzfrau(id: Int64) -> Putzfrau? { putzfrauen.first { $0.id == id } }
    func schluessel(id: Int64) -> Schluessel? { schluessel.first { $0.id == id } }

    func kundeName(id: Int64) -> String { kunde(id: id)?.name ?? "–" }
    func putzfrauName(id: Int64) -> String { putzfrau(id: id)?.name ?? "–" }
    func schluesselName(id: Int64) -> String { schluessel(id: id)?.bezeichnung ?? "–" }

    func aktuellerInhaber(schluesselId: Int64) -> Putzfrau? {
        guard let b = db.fetchAktiveBewegung(schluesselId: schluesselId) else { return nil }
        return putzfrau(id: b.putzfrauId)
    }

    func bewegungen(fuerSchluessel sid: Int64) -> [Bewegung] {
        db.fetchBewegungen(schluesselId: sid)
    }

    func bewegungen(fuerPutzfrau pid: Int64, nurOffen: Bool = false) -> [Bewegung] {
        db.fetchBewegungen(putzfrauId: pid, nurOffen: nurOffen)
    }

    var ueberfaelligeBewegungen: [Bewegung] {
        offeneBewegungen.filter { $0.status == .ueberfaellig }
    }

    var schluesselImUmlauf: Int {
        offeneBewegungen.map(\.schluesselId).unique.count
    }

    // MARK: - Kunden CRUD

    func kundeHinzufuegen(_ k: Kunde) {
        var neu = k
        neu.id = db.insertKunde(k)
        kunden.append(neu)
        kunden.sort { $0.name < $1.name }
    }

    func kundeAktualisieren(_ k: Kunde) {
        db.updateKunde(k)
        if let i = kunden.firstIndex(where: { $0.id == k.id }) { kunden[i] = k }
    }

    func kundeLöschen(id: Int64) {
        db.deleteKunde(id: id)
        kunden.removeAll { $0.id == id }
    }

    // MARK: - Putzfrauen CRUD

    func putzfrauHinzufuegen(_ p: Putzfrau) {
        var neu = p
        neu.id = db.insertPutzfrau(p)
        putzfrauen.append(neu)
        putzfrauen.sort { $0.name < $1.name }
    }

    func putzfrauAktualisieren(_ p: Putzfrau) {
        db.updatePutzfrau(p)
        if let i = putzfrauen.firstIndex(where: { $0.id == p.id }) { putzfrauen[i] = p }
    }

    func putzfrauLöschen(id: Int64) {
        db.deletePutzfrau(id: id)
        putzfrauen.removeAll { $0.id == id }
    }

    // MARK: - Schlüssel CRUD

    func schluesselHinzufuegen(_ s: Schluessel) {
        var neu = s
        neu.id = db.insertSchluessel(s)
        schluessel.append(neu)
        schluessel.sort { $0.bezeichnung < $1.bezeichnung }
    }

    func schluesselAktualisieren(_ s: Schluessel) {
        db.updateSchluessel(s)
        if let i = schluessel.firstIndex(where: { $0.id == s.id }) { schluessel[i] = s }
    }

    func schluesselAlsVerloren(_ s: Schluessel) {
        var updated = s
        updated.verloren = true
        db.updateSchluessel(updated)
        schluesselAktualisieren(updated)
        ladeAlles()
    }

    func schluesselLoeschen(id: Int64) {
        db.deleteSchluessel(id: id)
        schluessel.removeAll { $0.id == id }
    }

    // MARK: - Bewegungen

    func abgangErfassen(_ b: Bewegung) async {
        db.insertBewegung(b)

        if let faellig = b.erwarteteRueckgabe {
            let sName = schluesselName(id: b.schluesselId)
            let pName = putzfrauName(id: b.putzfrauId)
            await erinnerungen.erstelleRueckgabeErinnerung(
                schluesselName: sName,
                putzfrauName: pName,
                faelligAm: faellig
            )
        }
        ladeAlles()
    }

    func rueckgabeEintragen(bewegungId: Int64, datum: Date = Date()) {
        db.rueckgabeEintragen(bewegungId: bewegungId, datum: datum)
        ladeAlles()
    }

    func alleSchluesselRueck(vonPutzfrauId pid: Int64) {
        let offene = db.fetchBewegungen(putzfrauId: pid, nurOffen: true)
        for b in offene {
            db.rueckgabeEintragen(bewegungId: b.id)
        }
        ladeAlles()
    }

    func bewegungLoeschen(id: Int64) {
        db.deleteBewegung(id: id)
        ladeAlles()
    }
}

// MARK: - Sequence Helper

private extension Array where Element: Hashable {
    var unique: [Element] { Array(Set(self)) }
}
