import SwiftUI
import CoreData

@MainActor
class AppViewModel: ObservableObject {
    @Published var kunden: [Kunde] = []
    @Published var reinigungskraefte: [Reinigungskraft] = []
    @Published var offeneBewegungen: [Bewegung] = []
    @Published var alleBewegungen: [Bewegung] = []

    let erinnerungen = ErinnerungsService()

    private let kundenRepo: KundenRepository
    private let rkRepo: ReinigungskraftRepository
    private let bewegungRepo: BewegungRepository

    private var remoteChangeBeobachter: NSObjectProtocol?

    init(persistence: PersistenceController = .shared) {
        let ctx = persistence.viewContext
        self.kundenRepo   = KundenRepository(context: ctx)
        self.rkRepo       = ReinigungskraftRepository(context: ctx)
        self.bewegungRepo = BewegungRepository(context: ctx)

        ladeAlles()
        Task { await erinnerungen.zugriffAnfordern() }

        // Auf Änderungen aus CloudKit reagieren (Sync von anderen Geräten).
        remoteChangeBeobachter = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistence.container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.ladeAlles() }
        }
    }

    deinit {
        if let beobachter = remoteChangeBeobachter {
            NotificationCenter.default.removeObserver(beobachter)
        }
    }

    // MARK: - Laden

    func ladeAlles() {
        kunden            = kundenRepo.alleLaden()
        reinigungskraefte = rkRepo.alleLaden()
        alleBewegungen    = bewegungRepo.alleLaden()
        offeneBewegungen  = alleBewegungen.filter { $0.istOffen }
    }

    // MARK: - Lookup

    func kunde(id: UUID) -> Kunde? { kunden.first { $0.id == id } }
    func reinigungskraft(id: UUID) -> Reinigungskraft? { reinigungskraefte.first { $0.id == id } }

    func kundeName(id: UUID) -> String { kunde(id: id)?.name ?? "–" }
    func rkName(id: UUID) -> String { reinigungskraft(id: id)?.name ?? "–" }

    func aktiveBewegung(kundenId: UUID) -> Bewegung? {
        bewegungRepo.aktiveFuerKunde(kundenId)
    }

    func bewegungen(fuerKunde kid: UUID) -> [Bewegung] {
        bewegungRepo.fuerKunde(kid)
    }

    // Bewegungen wo diese RK als Stellvertretung eingesetzt ist
    func bewegungen(fuerStellvertretung rkId: UUID, nurOffen: Bool = false) -> [Bewegung] {
        bewegungRepo.fuerStellvertretung(rkId, nurOffen: nurOffen)
    }

    // Alle Kunden die dieser RK fest zugeteilt sind
    func zugeteilteKunden(rkId: UUID) -> [Kunde] {
        kunden.filter { $0.zugeteilteReinigungskraftId == rkId }
    }

    func zugeteilteReinigungskraft(kundenId: UUID) -> Reinigungskraft? {
        guard let k = kunde(id: kundenId), let rkId = k.zugeteilteReinigungskraftId
        else { return nil }
        return reinigungskraft(id: rkId)
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
        let neu = kundenRepo.anlegen(k)
        kunden.append(neu)
        kunden.sort { $0.name < $1.name }
    }

    func kundeAktualisieren(_ k: Kunde) {
        kundenRepo.aktualisieren(k)
        if let i = kunden.firstIndex(where: { $0.id == k.id }) { kunden[i] = k }
    }

    func kundeLoeschen(id: UUID) {
        kundenRepo.loeschen(id: id)
        kunden.removeAll { $0.id == id }
        ladeAlles()
    }

    // MARK: - Reinigungskräfte CRUD

    func rkHinzufuegen(_ r: Reinigungskraft) {
        let neu = rkRepo.anlegen(r)
        reinigungskraefte.append(neu)
        reinigungskraefte.sort { $0.name < $1.name }
    }

    func rkAktualisieren(_ r: Reinigungskraft) {
        rkRepo.aktualisieren(r)
        if let i = reinigungskraefte.firstIndex(where: { $0.id == r.id }) { reinigungskraefte[i] = r }
    }

    func rkLoeschen(id: UUID) {
        rkRepo.loeschen(id: id)
        reinigungskraefte.removeAll { $0.id == id }
        ladeAlles()
    }

    // MARK: - Bewegungen

    func schluesselEinfordern(_ b: Bewegung) async {
        bewegungRepo.anlegen(b)
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

    func rueckgabeEintragen(bewegungId: UUID, datum: Date = Date()) {
        bewegungRepo.rueckgabeEintragen(id: bewegungId, datum: datum)
        ladeAlles()
    }

    // Alle Stellvertreter-Schlüssel einer RK zurückgeben
    func alleStellvertretungsSchluesselZurueck(vonRKId rkId: UUID) {
        let offene = bewegungRepo.fuerStellvertretung(rkId, nurOffen: true)
        for b in offene { bewegungRepo.rueckgabeEintragen(id: b.id) }
        ladeAlles()
    }

    func bewegungAktualisieren(_ b: Bewegung) {
        bewegungRepo.aktualisieren(b)
        ladeAlles()
    }

    func bewegungLoeschen(id: UUID) {
        bewegungRepo.loeschen(id: id)
        ladeAlles()
    }

    // MARK: - Import (Stammdaten)

    func pfImportieren(_ items: [Reinigungskraft]) {
        for r in items { rkRepo.anlegen(r) }
        ladeAlles()
    }

    func kdImportieren(_ items: [Kunde]) {
        for k in items { kundenRepo.anlegen(k) }
        ladeAlles()
    }

    // Stellvertretung auf bestehender Bewegung setzen
    func stellvertretungSetzen(bewegungId: UUID, rkId: UUID?) {
        guard var b = offeneBewegungen.first(where: { $0.id == bewegungId }) else { return }
        b.stellvertretungRKId = rkId
        bewegungRepo.aktualisieren(b)
        ladeAlles()
    }
}
