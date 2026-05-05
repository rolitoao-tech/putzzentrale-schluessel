import EventKit
import Foundation

@MainActor
class ErinnerungsService: ObservableObject {
    private let store = EKEventStore()
    @Published var zugriffErteilt = false

    func zugriffAnfordern() async {
        let aktuellerStatus = EKEventStore.authorizationStatus(for: .reminder)
        print("[Erinnerungen] Aktueller Status: \(aktuellerStatus.rawValue)")

        if #available(macOS 14.0, *) {
            do {
                zugriffErteilt = try await store.requestFullAccessToReminders()
                print("[Erinnerungen] Zugriff erteilt: \(zugriffErteilt)")
            } catch {
                zugriffErteilt = false
                print("[Erinnerungen] Fehler bei Zugriffsanfrage: \(error)")
            }
        } else {
            zugriffErteilt = await withCheckedContinuation { cont in
                store.requestAccess(to: .reminder) { granted, fehler in
                    if let fehler { print("[Erinnerungen] Fehler: \(fehler)") }
                    cont.resume(returning: granted)
                }
            }
        }
    }

    @discardableResult
    func erstelleRueckgabeErinnerung(
        schluesselName: String,
        putzfrauName: String,
        faelligAm: Date
    ) async -> String? {
        guard zugriffErteilt else { return nil }

        let reminder = EKReminder(eventStore: store)
        reminder.title = "Schlüssel zurück: \(schluesselName)"
        reminder.notes = "Von \(putzfrauName) erwartet am \(faelligAm.anzeigeText)"

        // Gespeicherte Erinnerungsliste verwenden, sonst Standard
        let gespeicherteId = UserDefaults.standard.string(forKey: "erinnerungsKalenderId") ?? ""
        if !gespeicherteId.isEmpty,
           let kalender = store.calendar(withIdentifier: gespeicherteId) {
            reminder.calendar = kalender
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        var due = Calendar.current.dateComponents([.year, .month, .day], from: faelligAm)
        due.hour = 8
        reminder.dueDateComponents = due
        reminder.addAlarm(EKAlarm(relativeOffset: 0))

        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("Erinnerung konnte nicht erstellt werden: \(error)")
            return nil
        }
    }

    func markiereErledigt(identifier: String) {
        guard zugriffErteilt,
              let item = store.calendarItem(withIdentifier: identifier) as? EKReminder
        else { return }
        item.isCompleted = true
        try? store.save(item, commit: true)
    }

    // TEMPORÄR (nur DEBUG): Cleanup von Schlüssel-Erinnerungen für die Testdaten-Phase.
    // Mit dem Wartungs-Tab in EinstellungenView nach der Stammdaten-Migration entfernen.
    #if DEBUG
    // Löscht alle von dieser App erzeugten Schlüssel-Erinnerungen.
    // Erkennung über den Titel-Präfix "Schlüssel zurück:" – gilt für alle
    // Erinnerungs-Listen, unabhängig von der eingestellten Standard-Liste.
    @discardableResult
    func alleSchluesselErinnerungenLoeschen() async -> Int {
        guard zugriffErteilt else { return 0 }
        let kalender = store.calendars(for: .reminder)
        let praedikat = store.predicateForReminders(in: kalender)

        let reminders: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: praedikat) { result in
                cont.resume(returning: result ?? [])
            }
        }
        var anzahl = 0
        for r in reminders where (r.title ?? "").hasPrefix("Schlüssel zurück:") {
            do {
                try store.remove(r, commit: false)
                anzahl += 1
            } catch {
                print("[Erinnerungen] Löschen fehlgeschlagen: \(error)")
            }
        }
        do { try store.commit() } catch {
            print("[Erinnerungen] Commit fehlgeschlagen: \(error)")
        }
        return anzahl
    }
    #endif
}
