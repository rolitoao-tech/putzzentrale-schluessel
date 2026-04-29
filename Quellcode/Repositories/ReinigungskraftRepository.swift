import CoreData

// Datenzugriff für Reinigungskräfte.
final class ReinigungskraftRepository {
    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.ctx = context
    }

    func alleLaden() -> [Reinigungskraft] {
        let req = NSFetchRequest<CDReinigungskraft>(entityName: "CDReinigungskraft")
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let result = (try? ctx.fetch(req)) ?? []
        return result.map(Self.toStruct)
    }

    @discardableResult
    func anlegen(_ r: Reinigungskraft) -> Reinigungskraft {
        let cd = CDReinigungskraft(context: ctx)
        applyFields(r, on: cd)
        save()
        return Self.toStruct(cd)
    }

    func aktualisieren(_ r: Reinigungskraft) {
        guard let cd = finden(id: r.id) else { return }
        applyFields(r, on: cd)
        save()
    }

    func loeschen(id: UUID) {
        guard let cd = finden(id: id) else { return }
        ctx.delete(cd)
        save()
    }

    // MARK: - Helfer

    private func finden(id: UUID) -> CDReinigungskraft? {
        let req = NSFetchRequest<CDReinigungskraft>(entityName: "CDReinigungskraft")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    private func applyFields(_ r: Reinigungskraft, on cd: CDReinigungskraft) {
        if cd.id == nil { cd.id = r.id }
        cd.name    = r.name
        cd.aktiv   = r.aktiv
        cd.notizen = r.notizen
    }

    private func save() {
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("ReinigungskraftRepository.save: \(error)") }
    }

    static func toStruct(_ cd: CDReinigungskraft) -> Reinigungskraft {
        Reinigungskraft(
            id: cd.id ?? UUID(),
            name: cd.name ?? "",
            aktiv: cd.aktiv,
            notizen: cd.notizen ?? ""
        )
    }
}
