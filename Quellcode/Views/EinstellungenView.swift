import SwiftUI
import CloudKit
import EventKit

// Einstellungen-Fenster (cmd+,). Zeigt iCloud-/Sync-Status und Erinnerungs-Konfiguration.
struct EinstellungenView: View {
    var body: some View {
        TabView {
            iCloudTab
                .tabItem { Label("iCloud", systemImage: "icloud") }
            erinnerungenTab
                .tabItem { Label("Erinnerungen", systemImage: "bell") }
        }
        .frame(width: 480, height: 320)
        .padding()
    }

    // MARK: - iCloud-Tab

    @State private var iCloudStatusText: String = "Wird geprüft …"
    @State private var iCloudIstVerfuegbar: Bool = false

    private var iCloudTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iCloud / Synchronisation").font(.headline)

            HStack {
                Image(systemName: iCloudIstVerfuegbar ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(iCloudIstVerfuegbar ? .green : .orange)
                Text(iCloudStatusText)
            }

            Text("Container: \(PersistenceController.cloudKitContainerIdentifier)")
                .font(.caption).foregroundColor(.secondary)

            Divider()

            Text("Mehrbenutzer-Zugriff (Freigabe) wird in einer späteren Ausbaustufe ergänzt.")
                .font(.caption).foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await pruefeICloudStatus() }
    }

    private func pruefeICloudStatus() async {
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                iCloudIstVerfuegbar = true
                iCloudStatusText = "iCloud verfügbar – Daten werden synchronisiert."
            case .noAccount:
                iCloudStatusText = "Kein iCloud-Account angemeldet."
            case .restricted:
                iCloudStatusText = "iCloud-Zugriff ist eingeschränkt."
            case .couldNotDetermine:
                iCloudStatusText = "iCloud-Status konnte nicht ermittelt werden."
            case .temporarilyUnavailable:
                iCloudStatusText = "iCloud aktuell nicht verfügbar."
            @unknown default:
                iCloudStatusText = "Unbekannter iCloud-Status."
            }
        } catch {
            iCloudStatusText = "Fehler bei iCloud-Prüfung: \(error.localizedDescription)"
        }
    }

    // MARK: - Erinnerungen-Tab

    @State private var kalenderListe: [EKCalendar] = []
    @AppStorage("erinnerungsKalenderId") private var erinnerungsKalenderId: String = ""

    private var erinnerungenTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Erinnerungs-Liste").font(.headline)
            Text("Wähle, in welcher macOS-Erinnerungs-Liste neue Rückgabe-Erinnerungen abgelegt werden.")
                .font(.caption).foregroundColor(.secondary)

            Picker("Liste", selection: $erinnerungsKalenderId) {
                Text("Standard-Liste").tag("")
                ForEach(kalenderListe, id: \.calendarIdentifier) { k in
                    Text(k.title).tag(k.calendarIdentifier)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { ladeKalender() }
    }

    private func ladeKalender() {
        let store = EKEventStore()
        kalenderListe = store.calendars(for: .reminder)
    }
}
