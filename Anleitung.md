# Putzzentrale – Schlüsselverwaltung

Native macOS-App für die zentrale Verwaltung von Kunden-Schlüsseln und Reinigungskräften der PutzZentrale.ch Zürichsee GmbH.

## Voraussetzungen

- Xcode 16 oder neuer
- macOS 13 oder neuer (Deployment Target)
- iCloud-Account auf jedem Mac, der die App nutzt
- Apple Developer Programm (Team `9UUZ8K43EJ`)

## Projektstruktur

```
Quellcode/
├── PutzentraleApp.swift              App-Einstieg, injiziert PersistenceController
├── ContentView.swift                 NavigationSplitView mit Sidebar
├── Models/                           Wert-Structs (Kunde, Reinigungskraft, Bewegung)
├── Persistence/
│   ├── PersistenceController.swift   NSPersistentCloudKitContainer (Private + Shared Store)
│   └── Schluesselverwaltung.xcdatamodeld   Core-Data-Modell
├── Repositories/                     Mapping NSManagedObject ↔ Wert-Struct
├── ViewModels/AppViewModel.swift     Beobachtbare Listen, beobachtet CloudKit-Änderungen
├── Views/                            SwiftUI-Ansichten
│   ├── DashboardView.swift           Pendenzen-Übersicht, Kennzahlen
│   ├── SchluesselUebersichtView.swift Kunden-Liste mit Detailansicht
│   ├── BewegungErfassenView.swift    Schlüssel einfordern / Rückgabe
│   ├── EinstellungenView.swift       iCloud-Status, Erinnerungs-Liste
│   └── Stammdaten/
│       └── ReinigungskraefteView.swift
├── Services/ErinnerungsService.swift EventKit-Integration (lokal pro Mac)
└── Utilities/DateFormatters.swift    dd.MM.yyyy-Anzeige
```

## Datenmodell

Drei Entitäten:

| Entität          | Kernfelder |
|------------------|-----------|
| **Kunde**        | kundennummer, name, wohnort, zugeteilteReinigungskraft, aktiv, notizen |
| **Reinigungskraft** | name, aktiv, notizen |
| **Bewegung**     | kunde, datumAbgang, grund, stellvertretungRK, bueroAblage, erwarteteRueckgabe, datumRueckgabe, poolEingetragen, notizen, Audit-Felder |

IDs sind `UUID` (CloudKit-`recordName`). Status einer Bewegung wird **berechnet**: Offen / Überfällig / Zurück. Schlüssel sind keine eigene Entität – sie sind über die Beziehung Kunde ↔ Bewegung modelliert.

## Datenhaltung

Die App verwendet **Core Data + CloudKit** über `NSPersistentCloudKitContainer`:

- Daten werden lokal in einem Core-Data-SQLite-Store gehalten (im App-Container).
- CloudKit synchronisiert sie automatisch zwischen allen angemeldeten Macs.
- Über CloudKit Sharing (CKShare) können bis zu drei Mitarbeitende denselben Datenbestand sehen und bearbeiten.

Details siehe `ARCHITEKTUR_CLOUDKIT.md`.

**Lokaler Datenbankpfad** (intern, normalerweise nicht relevant):
```
~/Library/Containers/ch.pzschluessel/Data/Library/Application Support/Schluesselverwaltung.sqlite
```

## Erstes Setup (einmalig pro Mac)

1. **Apple-ID** in den macOS-Systemeinstellungen anmelden, **iCloud Drive aktiviert** lassen.
2. App starten — beim ersten Lauf:
   - macOS fragt nach Berechtigung für **Erinnerungen** (für Rückgabe-Termine).
   - Daten aus CloudKit werden automatisch geladen, sobald die Freigabe akzeptiert wurde.

## Apple-Developer-Setup (einmalig fürs Projekt)

Im Apple Developer Portal beim Team `9UUZ8K43EJ`:

1. App-ID `ch.pzschluessel` registrieren mit den Capabilities:
   - **iCloud (CloudKit)**
   - **Push Notifications**
2. CloudKit-Container `iCloud.ch.pzschluessel` erstellen.

Die Entitlements sind in `Quellcode/Schlüsselverwaltung.entitlements` bereits vorbereitet.

## Build und Start

1. Xcode-Projekt regenerieren (sofern nicht vorhanden):
   ```
   python3 generate_xcodeproj.py
   ```
2. `Schlüsselverwaltung.xcodeproj` in Xcode öffnen.
3. **⌘R** zum Starten.

Beim ersten Start fragt macOS nach Erinnerungen-Berechtigung.

## Mehrbenutzer (3 Mitarbeitende, alle sehen alles)

Eine Person erstellt den Datenbestand und teilt ihn per CloudKit-Sharing mit den anderen zwei Macs. Die geteilten Daten erscheinen automatisch.

> **Hinweis**: Die Sharing-UI (Freigabe-Sheet) wird in einer späteren Ausbaustufe in den Einstellungen ergänzt.

## Erinnerungen (EventKit)

EventKit-Erinnerungen sind **lokal pro Mac** – sie werden nicht synchronisiert. Wenn eine neue Bewegung erfasst wird, erstellt nur der erfassende Mac eine Erinnerung in der macOS-Erinnerungen-App.

Die zu verwendende Erinnerungs-Liste lässt sich in den App-Einstellungen (⌘,) auswählen.

## Wichtige fachliche Regeln

- Das **Büro ist die zentrale Drehscheibe** – Schlüssel gehen nicht direkt von Reinigungskraft zu Reinigungskraft.
- Schlüssel sind im Normalzustand bei der zugeteilten Reinigungskraft. Bei Ferien, Krankheit oder Einzel-Terminen werden sie eingefordert (Bewegung erfasst).
- Überfällige Bewegungen werden im Dashboard **rot** hervorgehoben.
- Pflichtfelder beim Erfassen einer Bewegung: Kunde, Grund, Ablage (Safe / Dossier / Stellvertretung), Pool-Eintrag im CRM.

## Backup

Bei CloudKit ist ein klassisches Backup nicht im selben Sinn nötig — Daten liegen auf Apples Servern und auf jedem angemeldeten Mac. Für ein Export-Feature siehe spätere Ausbaustufen.
