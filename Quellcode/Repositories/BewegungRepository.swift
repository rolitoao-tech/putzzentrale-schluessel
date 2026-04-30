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
        // Offen = noch nicht zurückgegeben UND nicht storniert
        req.predicate = NSPredicate(format: "datumRueckgabe == nil AND storniert == NO")
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
        // Aktive Bewegung = offen und nicht storniert
        req.predicate = NSPredicate(format: "kunde.id == %@ AND datumRueckgabe == nil AND storniert == NO", kundenId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "datumAbgang", ascending: false)]
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first.map(Self.toStruct)
    }

    func fuerStellvertretung(_ rkId: UUID, nurOffen: Bool) -> [Bewegung] {
        let req = NSFetchRequest<CDBewegung>(entityName: "CDBewegung")
        if nurOffen {
            req.predicate = NSPredicate(format: "stellvertretungRK.id == %@ AND datumRueckgabe == nil AND storniert == NO", rkId as CVarArg)
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

    // Storno (W10): nur für offene Bewegungen. Setzt Audit-Felder.
    func stornieren(id: UUID, begruendung: String, von: String = NSUserName()) {
        guard let cd = finden(id: id) else { return }
        guard cd.datumRueckgabe == nil, cd.storniert == false else { return }
        cd.storniert = true
        cd.stornoBegruendung = begruendung
        cd.storniertAm = Date()
        cd.storniertVon = von
        save()
    }

    // Prüfbedürftig-Marker setzen (durch W11-Cascade auf offene Bewegungen)
    func pruefbeduerftigSetzen(id: UUID, grund: String) {
        guard let cd = finden(id: id) else { return }
        cd.pruefbeduerftig = true
        cd.pruefbeduerftigGrund = grund
        cd.pruefbeduerftigAm = Date()
        save()
    }

    // Prüfbedürftig-Marker entfernen (User hat die Pendenz aufgelöst)
    func pruefbeduerftigEntfernen(id: UUID) {
        guard let cd = finden(id: id) else { return }
        cd.pruefbeduerftig = false
        cd.pruefbeduerftigGrund = nil
        cd.pruefbeduerftigAm = nil
        save()
    }

    // Hard-Delete: aktuell noch erlaubt. Wird in Schritt 4 (Storno-Workflow) gesperrt.
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
        cd.endgueltigeUebergabeAnKunde = b.endgueltigeUebergabeAnKunde
        // Audit-Felder Modifikation werden in Schritt 3 in den Mutations-Pfaden gesetzt,
        // hier nur durchschleifen, falls Caller sie schon setzt
        cd.modifiziertVon     = b.modifiziertVon
        cd.modifiziertAm      = b.modifiziertAm
        // Storno- und Prüfbedürftig-Felder laufen über eigene Methoden (siehe oben),
        // applyFields schleift den geladenen Stand nur durch
        cd.storniert          = b.storniert
        cd.stornoBegruendung  = b.stornoBegruendung
        cd.storniertAm        = b.storniertAm
        cd.storniertVon       = b.storniertVon
        cd.pruefbeduerftig    = b.pruefbeduerftig
        cd.pruefbeduerftigGrund = b.pruefbeduerftigGrund
        cd.pruefbeduerftigAm  = b.pruefbeduerftigAm
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
            endgueltigeUebergabeAnKunde: cd.endgueltigeUebergabeAnKunde,
            erstelltVon:         cd.erstelltVon ?? "",
            erstelltAm:          cd.erstelltAm,
            modifiziertVon:      cd.modifiziertVon ?? "",
            modifiziertAm:       cd.modifiziertAm,
            storniert:           cd.storniert,
            stornoBegruendung:   cd.stornoBegruendung,
            storniertAm:         cd.storniertAm,
            storniertVon:        cd.storniertVon,
            pruefbeduerftig:     cd.pruefbeduerftig,
            pruefbeduerftigGrund: cd.pruefbeduerftigGrund,
            pruefbeduerftigAm:   cd.pruefbeduerftigAm
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
