# Putzzentrale – Schlüsselverwaltung

## Arbeitsweise

- **Schrittweise vorgehen**: Nach jedem abgeschlossenen Schritt auf Bestätigung warten, bevor der nächste beginnt.
- **Bei zwei Lösungswegen**: Beide kurz erklären (max. 2–3 Sätze pro Option), Vor-/Nachteile nennen und fragen, welchen Weg der User bevorzugt.
- **Kein Over-Engineering**: So einfach wie möglich. Keine Abstraktionen, die nicht sofort gebraucht werden.

## Git

- Nach jedem abgeschlossenen Feature einen Commit erstellen.
- Commit-Beschreibungen auf **Deutsch**.
- Commits nur auf explizite Anfrage des Users erstellen.

## Code-Stil

- Code-Kommentare auf **Deutsch**.
- App-Sprache: **Deutsch**.
- Datumsformat durchgehend: **dd.MM.yyyy** (Schweizer Standard).
- Keine englischen Bezeichnungen in UI-Texten, Labels oder Fehlermeldungen.

## Technologie

- Swift / SwiftUI, nativ macOS (kein iOS, kein iPadOS).
- Datenbank: SQLite3 (direkt, kein ORM, kein SPM-Paket).
- Keine CloudKit-Sync, kein iCloud.
- EventKit für macOS-Erinnerungen.

## Datenmodell (Überblick)

| Entität    | Kernfelder |
|------------|-----------|
| Kunde      | name, adresse, objekt, status (aktiv/inaktiv) |
| Putzfrau   | name, telefon, email, status (aktiv/krank/ferien/inaktiv) |
| Schlüssel  | bezeichnung, kunde_id, anzahl_kopien, verloren |
| Bewegung   | schluessel_id, datum_abgang, putzfrau_id, grund, erwartete_rueckgabe, datum_rueckgabe |

Status einer Bewegung wird **berechnet**: Offen / Überfällig / Zurück.

## Wichtige Regeln (fachlich)

- Das **Büro ist immer die zentrale Drehscheibe** – Schlüssel gehen nie direkt von Putzfrau zu Putzfrau.
- Jede Schlüsselausgabe (Abgang vom Büro) und Rücknahme (Rückgabe ans Büro) wird als Bewegung erfasst.
- Überfällige Bewegungen werden **rot** hervorgehoben.
