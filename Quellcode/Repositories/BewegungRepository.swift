import CoreData

// Datenzugriff für Bewegungen. Status wird nicht persistiert, sondern berechnet.
final class BewegungRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.ctx = context
    }

    // MARK: - Lesen

    func alleLaden() -> [Bewegung] {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        req.sortDescriptors = [NSSortDescriptor(key: "datumAbgang", ascending: false)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    func offene() -> [Bewegung] {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        req.predicate = NSPredicate(format: "datumRueckgabe == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "erwarteteRueckgabe", ascending: true)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    func fuerKunde(_ kundenId: UUID) -> [Bewegung] {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        req.predicate = NSPredicate(format: "kunde.id == %@", kundenId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "datumAbgang", ascending: false)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    func aktiveFuerKunde(_ kundenId: UUID) -> Bewegung? {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        req.predicate = NSPredicate(format: "kunde.id == %@ AND datumRueckgabe == nil", kundenId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "datumAbgang", ascending: false)]
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first.map(Self.toStruct)
    }

    func fuerStellvertretung(_ rkId: UUID, nurOffen: Bool) -> [Bewegung] {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        if nurOffen {
            req.predicate = NSPredicate(format: "stellvertretungRK.id == %@ AND datumRueckgabe == nil", rkId as CVarArg)
        } else {
            req.predicate = NSPredicate(format: "stellvertretungRK.id == %@", rkId as CVarArg)
        }
        req.sortDescriptors = [NSSortDescriptor(key: "datumAbgang", ascending: false)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    // MARK: - Schreiben

    @discardableResult
    func anlegen(_ b: Bewegung) -> Bewegung {
        let cd = CDBewegung(context: ctx)
        cd.id          = b.id
        cd.erstelltVon = NSUserName()
        cd.erstelltAm  = Date()
        applyFields(b, on: cd)
        save()
        return Self.toStruct(cd)
    }

    func aktualisieren(_ b: Bewegung) {
        guard let cd = finden(id: b.id) else { return }
        applyFields(b, on: cd)
        save()
    }

    func rueckgabeEintragen(id: UUID, datum: Date = Date()) {
        guard let cd = finden(id: id) else { return }
        cd.datumRueckgabe = datum
        save()
    }

    func loeschen(id: UUID) {
        guard let cd = finden(id: id) else { return }
        ctx.delete(cd)
        save()
    }

    // MARK: - Helfer

    private func finden(id: UUID) -> CDBewegung? {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    private func applyFields(_ b: Bewegung, on cd: CDBewegung) {
        cd.kunde              = Self.findKunde(id: b.kundenId, ctx: ctx)
        cd.datumAbgang        = b.datumAbgang
        cd.grund              = b.grund.rawValue
        cd.stellvertretungRK  = b.stellvertretungRKId.flatMap { Self.findRK(id: $0, ctx: ctx) }
        cd.bueroAblage        = b.bueroAblage?.rawValue
        cd.bueroAblageDetail  = b.bueroAblageDetail
        cd.erwarteteRueckgabe = b.erwarteteRueckgabe
        cd.datumRueckgabe     = b.datumRueckgabe
        cd.poolEingetragen    = b.poolEingetragen
        cd.notizen            = b.notizen
    }

    private func save() {
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("BewegungRepository.save: \(error)") }
    }

    // MARK: - Mapping

    static func toStruct(_ cd: CDBewegung) -> Bewegung {
        Bewegung(
            id:                  cd.id ?? UUID(),
            kundenId:            cd.kunde?.id ?? UUID(),
            datumAbgang:         cd.datumAbgang ?? Date(),
            grund:               BewegungGrund(rawValue: cd.grund ?? "") ?? .einzelTermin,
            stellvertretungRKId: cd.stellvertretungRK?.id,
            bueroAblage:         cd.bueroAblage.flatMap { BueroAblage(rawValue: $0) },
            bueroAblageDetail:   cd.bueroAblageDetail ?? "",
            erwarteteRueckgabe:  cd.erwarteteRueckgabe,
            datumRueckgabe:      cd.datumRueckgabe,
            poolEingetragen:     cd.poolEingetragen,
            notizen:             cd.notizen ?? "",
            erstelltVon:         cd.erstelltVon ?? "",
            erstelltAm:          cd.erstelltAm
        )
    }

    private static func findKunde(id: UUID, ctx: NSManagedObjectContext) -> CDKunde? {
        let req = NSFetchRequest<CDKunde>(entityName: "CDKunde")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    private static func findRK(id: UUID, ctx: NSManagedObjectContext) -> CDReinigungskraft? {
        let req = NSFetchRequest<CDReinigungskraft>(entityName: "CDReinigungskraft")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }
}
