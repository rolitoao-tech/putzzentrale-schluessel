import CoreData

// Datenzugriff für Kunden. Mappt zwischen Core-Data-Entity (CDKunde) und Wert-Struct (Kunde).
final class KundenRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.ctx = context
    }

    // MARK: - Lesen

    func alleLaden() -> [Kunde] {
        let req = NSFetchRequest<CDKunde>(entityName: "CDKunde")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    // MARK: - Schreiben

    @discardableResult
    func anlegen(_ k: Kunde) -> Kunde {
        let cd = CDKunde(context: ctx)
        Self.applyFields(k, on: cd, ctx: ctx)
        save()
        return Self.toStruct(cd)
    }

    func aktualisieren(_ k: Kunde) {
        guard let cd = finden(id: k.id) else { return }
        Self.applyFields(k, on: cd, ctx: ctx)
        save()
    }

    // Vertragsende (W4/W5): markiert den Kunde als inaktiv mit Audit-Datum.
    func vertragBeenden(id: UUID, datum: Date, von: String = NSUserName()) {
        guard let cd = finden(id: id) else { return }
        cd.aktiv = false
        cd.schluesselZurueckgegebenAm = datum
        cd.schluesselZurueckgegebenVon = von
        save()
    }

    // Reaktivierung (W6): leert die Vertragsende-Felder, setzt aktiv = true.
    // Schlüssel-Standort danach ist offen — User soll W11 ausführen.
    func reaktivieren(id: UUID) {
        guard let cd = finden(id: id) else { return }
        cd.aktiv = true
        cd.schluesselZurueckgegebenAm = nil
        cd.schluesselZurueckgegebenVon = nil
        save()
    }

    // Manueller Standort (W11): Übersteuerung mit Pflicht-Notiz und Audit.
    func standortManuellSetzen(
        id: UUID,
        typ: ManuellerStandortTyp,
        stellvRKId: UUID?,
        notiz: String,
        von: String = NSUserName()
    ) {
        guard let cd = finden(id: id) else { return }
        cd.standortManuellAm = Date()
        cd.standortManuellVon = von
        cd.standortManuellNotiz = notiz
        cd.standortManuellTyp = typ.rawValue
        cd.standortManuellStellvRKId = (typ == .beiStellv) ? stellvRKId : nil
        save()
    }

    // Hard-Delete: aktuell nur prüfen wir nicht auf Bewegungen — wird in Schritt 7 ergänzt.
    func loeschen(id: UUID) {
        guard let cd = finden(id: id) else { return }
        ctx.delete(cd)
        save()
    }

    // MARK: - Helfer

    private func finden(id: UUID) -> CDKunde? {
        let req = NSFetchRequest<CDKunde>(entityName: "CDKunde")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    private func save() {
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("KundenRepository.save: \(error)") }
    }

    // MARK: - Mapping

    static func toStruct(_ cd: CDKunde) -> Kunde {
        Kunde(
            id: cd.id ?? UUID(),
            kundennummer: cd.kundennummer ?? "",
            name: cd.name ?? "",
            wohnort: cd.wohnort ?? "",
            zugeteilteReinigungskraftId: cd.zugeteilteReinigungskraft?.id,
            aktiv: cd.aktiv,
            notizen: cd.notizen ?? "",
            schluesselZurueckgegebenAm: cd.schluesselZurueckgegebenAm,
            schluesselZurueckgegebenVon: cd.schluesselZurueckgegebenVon,
            standortManuellAm: cd.standortManuellAm,
            standortManuellVon: cd.standortManuellVon,
            standortManuellNotiz: cd.standortManuellNotiz,
            standortManuellTyp: cd.standortManuellTyp.flatMap { ManuellerStandortTyp(rawValue: $0) },
            standortManuellStellvRKId: cd.standortManuellStellvRKId
        )
    }

    fileprivate static func applyFields(_ k: Kunde, on cd: CDKunde, ctx: NSManagedObjectContext) {
        if cd.id == nil { cd.id = k.id }
        cd.kundennummer = k.kundennummer
        cd.name         = k.name
        cd.wohnort      = k.wohnort
        cd.aktiv        = k.aktiv
        cd.notizen      = k.notizen
        // Vertragsende- und manueller-Standort-Felder laufen über eigene Methoden,
        // applyFields schleift den geladenen Stand nur durch (Round-Trip-Sicherheit)
        cd.schluesselZurueckgegebenAm  = k.schluesselZurueckgegebenAm
        cd.schluesselZurueckgegebenVon = k.schluesselZurueckgegebenVon
        cd.standortManuellAm           = k.standortManuellAm
        cd.standortManuellVon          = k.standortManuellVon
        cd.standortManuellNotiz        = k.standortManuellNotiz
        cd.standortManuellTyp          = k.standortManuellTyp?.rawValue
        cd.standortManuellStellvRKId   = k.standortManuellStellvRKId

        if let rkId = k.zugeteilteReinigungskraftId {
            cd.zugeteilteReinigungskraft = Self.findRK(id: rkId, ctx: ctx)
        } else {
            cd.zugeteilteReinigungskraft = nil
        }
    }

    private static func findRK(id: UUID, ctx: NSManagedObjectContext) -> CDReinigungskraft? {
        let req = NSFetchRequest<CDReinigungskraft>(entityName: "CDReinigungskraft")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }
}
