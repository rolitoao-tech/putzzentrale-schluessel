import SwiftUI

@main
struct PutzentraleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            EinstellungenView()
        }
    }
}
