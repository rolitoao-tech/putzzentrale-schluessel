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

        // CloudKit-Schema einmalig pushen. Der Versions-Key wird bei jeder
        // Schema-Erweiterung hochgezählt, damit neue Felder nach Modell-Updates
        // automatisch in CloudKit publiziert werden.
        #if DEBUG
        let schemaKey = "cloudKitSchemaInitialisiert_v2"
        if !inMemory && !UserDefaults.standard.bool(forKey: schemaKey) {
            do {
                try container.initializeCloudKitSchema(options: [])
                UserDefaults.standard.set(true, forKey: schemaKey)
                print("CloudKit-Schema erfolgreich initialisiert (v2).")
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
