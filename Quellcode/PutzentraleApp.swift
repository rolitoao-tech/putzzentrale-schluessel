import SwiftUI

@main
struct PutzentraleApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.viewContext)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            EinstellungenView()
                .environment(\.managedObjectContext, persistence.viewContext)
        }
    }
}
