import SwiftUI

// Notifications zum Anstossen der Importe aus dem Menü.
// ContentView observiert diese und öffnet den File-Picker.
extension Notification.Name {
    static let importPFStarten = Notification.Name("importPFStarten")
    static let importKDStarten = Notification.Name("importKDStarten")
}

@main
struct PutzentraleApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .frame(minWidth: 900, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 780)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Stammdaten") {
                Button("PF importieren …") {
                    NotificationCenter.default.post(name: .importPFStarten, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("KD importieren …") {
                    NotificationCenter.default.post(name: .importKDStarten, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        Settings {
            EinstellungenView()
                .environment(\.managedObjectContext, persistence.viewContext)
        }
    }
}
