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
            firma: cd.firma ?? "",
            strasse: cd.strasse ?? "",
            plz: cd.plz ?? "",
            wohnort: cd.wohnort ?? "",
            telefon: cd.telefon ?? "",
            mobil: cd.mobil ?? "",
            email: cd.email ?? "",
            auftragsnummer: cd.auftragsnummer ?? "",
            zugeteilteReinigungskraftId: cd.zugeteilteReinigungskraft?.id,
            aktiv: cd.aktiv,
            notizen: cd.notizen ?? ""
        )
    }

    fileprivate static func applyFields(_ k: Kunde, on cd: CDKunde, ctx: NSManagedObjectContext) {
        if cd.id == nil { cd.id = k.id }
        cd.kundennummer   = k.kundennummer
        cd.name           = k.name
        cd.firma          = k.firma
        cd.strasse        = k.strasse
        cd.plz            = k.plz
        cd.wohnort        = k.wohnort
        cd.telefon        = k.telefon
        cd.mobil          = k.mobil
        cd.email          = k.email
        cd.auftragsnummer = k.auftragsnummer
        cd.aktiv          = k.aktiv
        cd.notizen        = k.notizen

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
