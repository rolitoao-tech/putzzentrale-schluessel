import SwiftUI
import CloudKit
import CoreData
import EventKit

// Einstellungen-Fenster (cmd+,). Zeigt iCloud-/Sync-Status, Erinnerungs-Konfiguration
// und Datenbank-Wartung (Reset).
struct EinstellungenView: View {
    var body: some View {
        TabView {
            iCloudTab
                .tabItem { Label("iCloud", systemImage: "icloud") }
            erinnerungenTab
                .tabItem { Label("Erinnerungen", systemImage: "bell") }
            #if DEBUG
            wartungTab
                .tabItem { Label("Wartung", systemImage: "wrench.and.screwdriver") }
            #endif
        }
        .frame(width: 480, height: 360)
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

    // MARK: - Wartungs-Tab (TEMPORÄR — nur DEBUG)
    //
    // Dieser Tab dient ausschliesslich zum Aufbau-/Bereinigungsphase mit Testdaten.
    // Nach erfolgreichem Stammdaten-Import und Übergabe an den Echtbetrieb soll
    // der gesamte Block (inkl. wartungTab + alleDatenLoeschen + DEBUG-tabItem oben)
    // entfernt werden.

    #if DEBUG
    @State private var zeigeLoeschBestaetigung = false
    @State private var loeschErgebnis: String?
    @State private var loeschtGerade = false

    private var wartungTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datenbank-Wartung").font(.headline)
            Text("Löscht alle KD, PF und Bewegungen aus der lokalen DB. Über CloudKit wird die Löschung auf alle verbundenen Geräte synchronisiert. Ausserdem werden alle von dieser App erzeugten Schlüssel-Erinnerungen entfernt.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                zeigeLoeschBestaetigung = true
            } label: {
                Label(loeschtGerade ? "Lösche …" : "Alle Daten zurücksetzen …",
                      systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(loeschtGerade)

            if let r = loeschErgebnis {
                Text(r).font(.caption).foregroundColor(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            "Wirklich alle Daten löschen?",
            isPresented: $zeigeLoeschBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Alles löschen", role: .destructive) {
                Task { @MainActor in
                    loeschtGerade = true
                    loeschErgebnis = nil
                    let r = await alleDatenLoeschen()
                    loeschtGerade = false
                    loeschErgebnis = "Gelöscht: \(r.bewegungen) Bewegungen, \(r.kd) KD, \(r.pf) PF, \(r.erinnerungen) Erinnerungen."
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Nicht umkehrbar. Betrifft auch synchronisierte iCloud-Daten auf allen verbundenen Geräten.")
        }
    }

    @MainActor
    private func alleDatenLoeschen() async -> (kd: Int, pf: Int, bewegungen: Int, erinnerungen: Int) {
        let ctx = PersistenceController.shared.viewContext

        // Reihenfolge: Bewegungen zuerst (auch wenn Cascade greift, expliziter)
        let bw = (try? ctx.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDBewegung"))) ?? []
        let kd = (try? ctx.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDKunde"))) ?? []
        let pf = (try? ctx.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDReinigungskraft"))) ?? []

        let zaehler = (kd: kd.count, pf: pf.count, bewegungen: bw.count)

        for o in bw { ctx.delete(o) }
        for o in kd { ctx.delete(o) }
        for o in pf { ctx.delete(o) }
        do { try ctx.save() } catch {
            print("Fehler beim Löschen: \(error)")
        }

        // Erinnerungen aufräumen (eigene Service-Instanz, da hier kein VM verfügbar)
        let dienst = ErinnerungsService()
        await dienst.zugriffAnfordern()
        let anzahl = await dienst.alleSchluesselErinnerungenLoeschen()

        return (zaehler.kd, zaehler.pf, zaehler.bewegungen, anzahl)
    }
    #endif
}
