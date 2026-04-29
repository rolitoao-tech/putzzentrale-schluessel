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

    // Stellvertretung auf bestehender Bewegung setzen
    func stellvertretungSetzen(bewegungId: UUID, rkId: UUID?) {
        guard var b = offeneBewegungen.first(where: { $0.id == bewegungId }) else { return }
        b.stellvertretungRKId = rkId
        bewegungRepo.aktualisieren(b)
        ladeAlles()
    }

    // MARK: - Demo-Daten (nur für Test/Entwicklung)

    // Erzeugt 5 Reinigungskräfte und 20 Kunden mit gemischten Bewegungs-Zuständen.
    // Idempotent über Namens-Check: bestehende Demo-Daten werden nicht doppelt angelegt.
    func demoDatenErzeugen() {
        let rkNamen = ["Marina", "Sandra", "Elif", "Fatima", "Lisa"]
        var rkIds: [String: UUID] = [:]

        // RKs anlegen, falls noch nicht vorhanden
        for name in rkNamen {
            if let bestehend = reinigungskraefte.first(where: { $0.name == name }) {
                rkIds[name] = bestehend.id
            } else {
                var rk = Reinigungskraft()
                rk.name = name
                let neu = rkRepo.anlegen(rk)
                rkIds[name] = neu.id
            }
        }

        // Kunden mit Zuteilung
        let demoKunden: [(nr: String, name: String, ort: String, rk: String)] = [
            ("2001", "Müller, Hans",        "Zürich",       "Marina"),
            ("2002", "Weber, Anna",         "Zürich",       "Marina"),
            ("2003", "Schneider, Tom",      "Küsnacht",     "Marina"),
            ("2004", "Keller, Sophie",      "Erlenbach",    "Marina"),
            ("2005", "Bauer, Markus",       "Männedorf",    "Marina"),
            ("2006", "Frei, Petra",         "Zürich",       "Sandra"),
            ("2007", "Huber, Robert",       "Horgen",       "Sandra"),
            ("2008", "Meier, Lisa",         "Wädenswil",    "Sandra"),
            ("2009", "Wagner, Jan",         "Stäfa",        "Sandra"),
            ("2010", "Roth, Claudia",       "Meilen",       "Elif"),
            ("2011", "Schmid, David",       "Herrliberg",   "Elif"),
            ("2012", "Brunner, Sabine",     "Zollikon",     "Elif"),
            ("2013", "Steiner, Felix",      "Küsnacht",     "Elif"),
            ("2014", "Frey, Nicole",        "Thalwil",      "Fatima"),
            ("2015", "Lang, Patrick",       "Rüschlikon",   "Fatima"),
            ("2016", "Gerber, Andrea",      "Kilchberg",    "Fatima"),
            ("2017", "Kunz, Daniel",        "Zürich",       "Lisa"),
            ("2018", "Walter, Eva",         "Zürich",       "Lisa"),
            ("2019", "Iten, Stefan",        "Adliswil",     "Lisa"),
            ("2020", "Hofer, Ursula",       "Langnau a.A.", "Lisa"),
        ]

        var kundenIds: [String: UUID] = [:]

        for d in demoKunden {
            if let bestehend = kunden.first(where: { $0.kundennummer == d.nr }) {
                kundenIds[d.nr] = bestehend.id
                continue
            }
            var k = Kunde()
            k.kundennummer = d.nr
            k.name = d.name
            k.wohnort = d.ort
            k.zugeteilteReinigungskraftId = rkIds[d.rk]
            let neu = kundenRepo.anlegen(k)
            kundenIds[d.nr] = neu.id
        }

        // Bewegungen mit verschiedenen Zuständen
        // (Nr, Tage in Vergangenheit für Abgang, Tage erwartet zurück, Ablage, Stellv. RK)
        struct DemoBewegung {
            let kundenNr: String
            let tageAbgang: Int  // negativ = in Vergangenheit
            let tageErwartet: Int
            let ablage: BueroAblage?
            let stellvRK: String?
        }

        let demoBewegungen: [DemoBewegung] = [
            // Marina – 1 unterwegs (Safe)
            DemoBewegung(kundenNr: "2001", tageAbgang: -3, tageErwartet: 4, ablage: .safe, stellvRK: nil),
            // Sandra – 2 unterwegs (1 Stellv bei Marina, 1 Dossier)
            DemoBewegung(kundenNr: "2006", tageAbgang: -5, tageErwartet: 2, ablage: nil, stellvRK: "Marina"),
            DemoBewegung(kundenNr: "2007", tageAbgang: -1, tageErwartet: 6, ablage: .dossier, stellvRK: nil),
            // Elif – 1 überfällig (Safe)
            DemoBewegung(kundenNr: "2010", tageAbgang: -10, tageErwartet: -2, ablage: .safe, stellvRK: nil),
            // Fatima – 1 Stellv bei Lisa
            DemoBewegung(kundenNr: "2014", tageAbgang: -2, tageErwartet: 5, ablage: nil, stellvRK: "Lisa"),
            // Lisa – 0 unterwegs
        ]

        let kalender = Calendar.current
        let heute = Date()

        for d in demoBewegungen {
            guard let kid = kundenIds[d.kundenNr] else { continue }
            // Falls bereits eine offene Bewegung existiert, überspringen
            if vm_aktiveBewegungVorhanden(kundenId: kid) { continue }

            var b = Bewegung()
            b.kundenId = kid
            b.datumAbgang = kalender.date(byAdding: .day, value: d.tageAbgang, to: heute) ?? heute
            b.grund = .einzelTermin
            b.erwarteteRueckgabe = kalender.date(byAdding: .day, value: d.tageErwartet, to: heute)
            if let stellv = d.stellvRK {
                b.stellvertretungRKId = rkIds[stellv]
            } else {
                b.bueroAblage = d.ablage
            }
            b.erstelltVon = "Demo"
            b.erstelltAm = heute
            bewegungRepo.anlegen(b)
        }

        ladeAlles()
    }

    private func vm_aktiveBewegungVorhanden(kundenId: UUID) -> Bool {
        bewegungRepo.aktiveFuerKunde(kundenId) != nil
    }
}
