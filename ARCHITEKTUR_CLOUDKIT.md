# Architektur — CloudKit-basierte Datenhaltung

Dieses Dokument beschreibt die Zielarchitektur für die Mehrbenutzer-Datenhaltung der App **Putzzentrale – Schlüsselverwaltung**.

## Ziel

Drei Mitarbeitende der PutzZentrale.ch arbeiten parallel auf je einem eigenen Mac mit derselben Datenbasis (Kunden, Reinigungskräfte, Bewegungen). Alle drei sehen denselben vollständigen Datenbestand.

## Warum nicht SQLite in iCloud Drive

Eine einzelne SQLite-Datei in `~/Library/Mobile Documents/com~apple~CloudDocs` ist nicht für gleichzeitigen Schreibzugriff mehrerer Geräte gedacht:

- iCloud Drive synchronisiert Dateien als opaken Blob – keine zeilenweise Konfliktauflösung.
- WAL-Dateien (`*-wal`, `*-shm`) werden zwar mitsynchronisiert, aber nicht atomar zusammen mit der Hauptdatei.
- Zwei gleichzeitige Schreibvorgänge führen zu „in conflict"-Kopien und im schlimmsten Fall zu Datenverlust.

## Warum CloudKit

- Apple-natives Backend, keine eigenen Server.
- Pro-Datensatz-Synchronisation, automatische Konfliktauflösung, Push-basierte Benachrichtigungen.
- Bestehender Apple-ID-Login auf jedem Mac genügt – kein eigenes Login-System nötig.
- Speicher und Traffic für unseren Datenumfang (wenige tausend Records) kostenlos im Free-Tier.

## Warum NSPersistentCloudKitContainer (Core Data + CloudKit)

Statt direkt gegen `CKDatabase`/`CKRecord` zu programmieren, verwenden wir Apples Wrapper `NSPersistentCloudKitContainer`. Begründung:

| Aspekt | Direktes CloudKit | NSPersistentCloudKitContainer |
|---|---|---|
| Offline-Cache | selbst zu bauen | gratis (lokaler Core-Data-Store) |
| Subscriptions / Push | manuell | automatisch |
| Konfliktbehandlung | manuell | automatisch (Last-Writer-Wins, anpassbar) |
| Sharing zwischen Benutzern | CKShare manuell | Standard-Sharing-Sheet integriert |
| Code-Umfang | hoch | niedrig |

Der bestehende SQLite-Code wird ersetzt. Daten in der bisherigen SQLite-DB sind reine Testdaten und müssen nicht migriert werden.

## Container und Identifiers

| | Wert |
|---|---|
| Apple Developer Team | Roland Kunz (`9UUZ8K43EJ`) |
| Bundle Identifier | `ch.pzschluessel` |
| CloudKit Container | `iCloud.ch.pzschluessel` |
| App-Sandbox | aktiviert (Voraussetzung für CloudKit) |

## Datenmodell (Core-Data-Entities)

Die drei bestehenden Entitäten werden 1:1 auf Core-Data-Entities abgebildet. IDs werden auf `UUID` umgestellt (CloudKit-`recordName`).

### `CDKunde`

| Attribut | Typ | Hinweis |
|---|---|---|
| id | UUID | recordName |
| kundennummer | String | |
| name | String | |
| wohnort | String | optional |
| zugeteilteReinigungskraft | Beziehung → CDReinigungskraft | optional |
| aktiv | Bool | |
| notizen | String | optional |

### `CDReinigungskraft`

| Attribut | Typ |
|---|---|
| id | UUID |
| name | String |
| aktiv | Bool |
| notizen | String |

### `CDBewegung`

| Attribut | Typ | Hinweis |
|---|---|---|
| id | UUID | |
| kunde | Beziehung → CDKunde | pflicht |
| datumAbgang | Date | |
| grund | String | Enum-Rawvalue |
| stellvertretungRK | Beziehung → CDReinigungskraft | optional |
| bueroAblage | String? | Enum-Rawvalue |
| bueroAblageDetail | String | |
| erwarteteRueckgabe | Date? | |
| datumRueckgabe | Date? | |
| poolEingetragen | Bool | |
| notizen | String | |
| erstelltVon | String | Audit |
| erstelltAm | Date? | Audit |

**Status wird nicht gespeichert** — er wird in der Swift-`Bewegung`-Struct aus `datumRueckgabe` und `erwarteteRueckgabe` berechnet.

CloudKit-Anforderungen, die das Modell erfüllen muss:
- Alle Attribute optional **oder** mit Default-Wert (CloudKit erlaubt keine non-optional ohne Default).
- Beziehungen müssen optional sein und einen Inversen haben.
- Keine `Unique Constraints` auf Attribut-Ebene (von CloudKit nicht unterstützt).

## Schichten

```
Views ──▶ AppViewModel ──▶ Repositories ──▶ PersistenceController ──▶ NSPersistentCloudKitContainer
                                                                                  │
                                                                                  ▼
                                                                              CloudKit
```

- **Views** kennen nur Wert-Structs (`Kunde`, `Reinigungskraft`, `Bewegung`).
- **AppViewModel** hält `@Published`-Listen, lädt via Repositories, beobachtet `NSPersistentStoreRemoteChange`.
- **Repositories** kapseln Core-Data-Zugriff, mappen `NSManagedObject` ↔ Wert-Struct.
- **PersistenceController** initialisiert den Container, konfiguriert Private + Shared Store für Sharing.

## Mehrbenutzer / Sharing

Bei „alle sehen alles" und 3 Benutzern wählen wir den einfachsten CloudKit-Sharing-Pfad:

1. Ein Benutzer (Silvia) startet die App und erstellt damit den Datenbestand in seiner **Private Database**.
2. Über das Standard-`UICloudSharingController`-Pendant für macOS (`NSSharingService` / `CKShare`) erzeugt sie einen Share-Link für den Datenbestand.
3. Die zwei anderen Mitarbeitenden öffnen den Link, akzeptieren auf ihrem Mac, und sehen die Daten ab dann in ihrer **Shared Database**.

`NSPersistentCloudKitContainer` unterstützt das mit zwei `NSPersistentStoreDescription`s — einer für `.private`, einer für `.shared`. Beide werden beim Start geladen; Core Data merged sie transparent.

Konkret:
- Owner-Mac (Silvia) sieht alle Records aus ihrem privaten Store.
- Teilnehmer-Macs sehen die geteilten Records aus ihrem `shared`-Store.
- Schreibrechte richten sich nach der Rolle im `CKShare` (Standard: lesen + schreiben).

In der App gibt es in den Einstellungen einen Bereich „iCloud / Synchronisation" mit:
- iCloud-Status (Account verfügbar, Container erreichbar)
- Aktion „Datenbestand teilen" (zeigt Share-Sheet)
- Aktion „Freigabe verwalten" (für Owner)
- Letzter erfolgreicher Sync, Sync-Fehler

## EventKit (Erinnerungen)

EventKit-Erinnerungen bleiben **lokal pro Benutzer/Mac**. Sie werden nicht über CloudKit synchronisiert. Das ist beabsichtigt: jeder Mitarbeitende hat seine eigene Erinnerungs-Liste in der macOS-Erinnerungen-App.

Wenn eine Bewegung erfasst wird, erstellt nur der erfassende Mac eine Erinnerung. Das ist akzeptabel, weil:
- Jeder Mac sieht überfällige Bewegungen ohnehin im Dashboard (rot markiert).
- Doppelte Erinnerungen auf 3 Macs wären für die Mitarbeitenden eher störend.

## Fehlerbehandlung

- **Kein iCloud-Account angemeldet**: App startet, zeigt Hinweis im Einstellungen-Bereich, lokaler Core-Data-Store funktioniert weiter.
- **Keine Netzwerkverbindung**: Core Data arbeitet lokal weiter, Sync setzt automatisch ein, sobald Netz da ist.
- **CKShare nicht akzeptiert**: Teilnehmer sieht leeren Datenbestand mit Hinweis „Bitte Einladung annehmen".
- **Konflikt**: Standard-Verhalten von `NSPersistentCloudKitContainer` ist Last-Writer-Wins basierend auf Modification Date — für unseren Use Case ausreichend.

## Apple-Developer-Setup (einmalig)

1. Im Apple Developer Portal beim Team `9UUZ8K43EJ`:
   - App-ID `ch.pzschluessel` mit den Capabilities **iCloud (CloudKit)** und **Push Notifications** registrieren.
   - CloudKit-Container `iCloud.ch.pzschluessel` erstellen.
2. Auf jedem Mac:
   - In iCloud angemeldet.
   - In den iCloud-Einstellungen ist „iCloud Drive" aktiviert (CloudKit-Container hängen daran, auch wenn wir iCloud Drive nicht direkt nutzen).
3. Auf dem Owner-Mac einmalig den Datenbestand teilen, die anderen zwei Macs annehmen lassen.

## Build und Start

- Xcode 16+
- macOS 13+ (Deployment Target)
- Beim ersten Start auf einem Mac: Apple-ID-Prompt, Erinnerungen-Berechtigung, dann fertig.
