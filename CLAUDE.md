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
- Datenhaltung: **Core Data + CloudKit** über `NSPersistentCloudKitContainer`.
- Bundle-ID: `ch.pzschluessel` · CloudKit-Container: `iCloud.ch.pzschluessel` (Team `9UUZ8K43EJ`).
- Mehrbenutzer-Zugriff über CloudKit Sharing (CKShare) — siehe `ARCHITEKTUR_CLOUDKIT.md`.
- App-Sandbox aktiviert (Voraussetzung für CloudKit).
- **Keine** SQLite-Datei in iCloud Drive – das wäre für mehrere parallele Schreibzugriffe nicht robust.
- EventKit für macOS-Erinnerungen (lokal pro Benutzer, kein Sync).

## Datenmodell (Überblick)

| Entität          | Kernfelder |
|------------------|-----------|
| Kunde            | kundennummer, name, wohnort, zugeteilteReinigungskraft, aktiv, notizen |
| Reinigungskraft  | name, aktiv, notizen |
| Bewegung         | kunde, datumAbgang, grund, stellvertretungRK, bueroAblage, erwarteteRueckgabe, datumRueckgabe, poolEingetragen, notizen, Audit-Felder |

IDs sind UUID-basiert (CloudKit-`recordName`). Status einer Bewegung wird **berechnet**: Offen / Überfällig / Zurück. Schlüssel sind keine eigene Entität — sie sind über die Beziehung Kunde ↔ Bewegung modelliert.

## Wichtige Regeln (fachlich)

- Das **Büro ist immer die zentrale Drehscheibe** – Schlüssel gehen nie direkt von Putzfrau zu Putzfrau.
- Jede Schlüsselausgabe (Abgang vom Büro) und Rücknahme (Rückgabe ans Büro) wird als Bewegung erfasst.
- Überfällige Bewegungen werden **rot** hervorgehoben.
