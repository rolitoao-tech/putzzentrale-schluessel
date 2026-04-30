import CoreData
import CloudKit

// Zentraler Core-Data-Stack mit CloudKit-Anbindung.
// Lädt zwei Stores: Private DB (eigene Daten) und Shared DB (von anderen geteilte Daten).
// NSPersistentCloudKitContainer kümmert sich um Sync, Push und Konflikte.
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    // CloudKit-Container-Identifier (siehe ARCHITEKTUR_CLOUDKIT.md)
    static let cloudKitContainerIdentifier = "iCloud.ch.pzschluessel"

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Schluesselverwaltung")

        // Private Store
        guard let privateDescription = container.persistentStoreDescriptions.first else {
            fatalError("Keine StoreDescription gefunden")
        }

        if inMemory {
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Remote-Change-Notifications aktivieren (für Sync-Updates aus CloudKit)
            privateDescription.setOption(true as NSNumber,
                                         forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber,
                                         forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Lightweight-Migration für Schema-Versionswechsel (v1 → v2 etc.)
            privateDescription.shouldMigrateStoreAutomatically = true
            privateDescription.shouldInferMappingModelAutomatically = true

            privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )
            privateDescription.cloudKitContainerOptions?.databaseScope = .private
        }

        // Shared Store (für Datenbestände, die andere Benutzer mit uns geteilt haben)
        if !inMemory {
            let sharedURL = privateDescription.url?
                .deletingLastPathComponent()
                .appendingPathComponent("Schluesselverwaltung-shared.sqlite")

            let sharedDescription = NSPersistentStoreDescription(url: sharedURL ?? URL(fileURLWithPath: "/dev/null"))
            sharedDescription.configuration = privateDescription.configuration
            sharedDescription.setOption(true as NSNumber,
                                        forKey: NSPersistentHistoryTrackingKey)
            sharedDescription.setOption(true as NSNumber,
                                        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            sharedDescription.shouldMigrateStoreAutomatically = true
            sharedDescription.shouldInferMappingModelAutomatically = true

            let sharedOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions

            container.persistentStoreDescriptions.append(sharedDescription)
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // Im Produktivbetrieb nicht crashen, sondern Fehler an UI weiterreichen.
                // Für die initiale Phase: laut scheitern, damit Setup-Fehler sofort sichtbar sind.
                print("Core-Data-Store konnte nicht geladen werden (\(description.url?.lastPathComponent ?? "?")): \(error)")
            }
        }

        // Änderungen aus dem jeweils anderen Store automatisch übernehmen
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // CloudKit-Schema einmalig pro Schema-Version pushen.
        // Flag-Name enthält die Schema-Version, damit nach einer Lightweight-Migration
        // das neue Schema (z.B. neue Attribute auf CDBewegung/CDKunde) auch in CloudKit landet.
        // initializeCloudKitSchema ist teuer und nur fürs Bootstrapping gedacht.
        #if DEBUG
        let schemaFlag = "cloudKitSchemaInitialisiert_v2"
        if !inMemory && !UserDefaults.standard.bool(forKey: schemaFlag) {
            do {
                try container.initializeCloudKitSchema(options: [])
                UserDefaults.standard.set(true, forKey: schemaFlag)
                print("CloudKit-Schema (v2) erfolgreich initialisiert.")
            } catch {
                print("CloudKit-Schema-Initialisierung fehlgeschlagen: \(error)")
            }
        }
        #endif
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Speichern mit Fehlerausgabe

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
}
