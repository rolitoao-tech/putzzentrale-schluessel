import EventKit
import Foundation

@MainActor
class ErinnerungsService: ObservableObject {
    private let store = EKEventStore()
    @Published var zugriffErteilt = false

    func zugriffAnfordern() async {
        if #available(macOS 14.0, *) {
            zugriffErteilt = (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            zugriffErteilt = await withCheckedContinuation { cont in
                store.requestAccess(to: .reminder) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    /// Erstellt eine Erinnerung und gibt den Kalender-Identifier zurück.
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
        reminder.calendar = store.defaultCalendarForNewReminders()

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

    /// Markiert eine Erinnerung als erledigt.
    func markiereErledigt(identifier: String) {
        guard zugriffErteilt,
              let item = store.calendarItem(withIdentifier: identifier) as? EKReminder
        else { return }
        item.isCompleted = true
        try? store.save(item, commit: true)
    }
}
