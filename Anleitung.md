# Xcode-Projekteinrichtung — Putzzentrale Schlüsselverwaltung

## Voraussetzungen

- Xcode 16 oder neuer
- macOS 26 (Deployment Target: macOS 13)

---

## 1. Neues Xcode-Projekt erstellen

1. Xcode öffnen → **File › New › Project**
2. Plattform: **macOS**
3. Template: **App**
4. Einstellungen:
   | Feld | Wert |
   |------|------|
   | Product Name | `Schlüsselverwaltung` |
   | Bundle Identifier | `ch.putzzentrale.schluessel` |
   | Interface | SwiftUI |
   | Language | Swift |
   | Storage | None |
5. Speicherort: **dieses Verzeichnis** (`Putzzentrale - Schlüsselverwaltung/`)

---

## 2. Quelldateien hinzufügen

Die vorhandenen Swift-Dateien aus `Quellcode/` ins Xcode-Projekt ziehen:

```
Quellcode/
├── PutzentraleApp.swift        → ersetzt die generierte App-Datei
├── ContentView.swift           → ersetzt die generierte ContentView
├── Utilities/
│   └── DateFormatters.swift
├── Models/
│   ├── Kunde.swift
│   ├── Putzfrau.swift
│   ├── Schluessel.swift
│   └── Bewegung.swift
├── Database/
│   └── DatabaseManager.swift
├── ViewModels/
│   └── AppViewModel.swift
├── Views/
│   ├── DashboardView.swift
│   ├── SchluesselListView.swift
│   ├── SchluesselDetailView.swift
│   ├── BewegungErfassenView.swift
│   └── Stammdaten/
│       ├── KundenView.swift
│       ├── PutzfrauenView.swift
│       └── SchluesselVerwaltungView.swift
└── Services/
    └── ErinnerungsService.swift
```

**Wichtig beim Import:** Häkchen bei **"Copy items if needed"** setzen.

---

## 3. Framework hinzufügen

Für macOS-Erinnerungen wird EventKit benötigt:

1. Projekt in der Sidebar anklicken → Target **Schlüsselverwaltung**
2. Tab **General** → Abschnitt **Frameworks, Libraries, and Embedded Content**
3. **+** → `EventKit.framework` suchen und hinzufügen

---

## 4. Info.plist anpassen

Im **Info.plist** (oder unter Target → Info) folgenden Eintrag hinzufügen:

| Key | Value |
|-----|-------|
| `NSRemindersUsageDescription` | `Putzzentrale erstellt Erinnerungen für Schlüssel-Rückgabetermine.` |

---

## 5. Entitlements anpassen

In der Datei `Schlüsselverwaltung.entitlements` (wird von Xcode automatisch erstellt):

```xml
<key>com.apple.security.personal-information.reminders</key>
<true/>
```

So navigieren: Target → **Signing & Capabilities** → **+** → **Reminders**

---

## 6. Deployment Target setzen

Target → **General** → **Minimum Deployments**:
- macOS: **13.0**

---

## 7. Datenbankpfad

Die SQLite-Datenbank wird automatisch erstellt unter:

```
~/Library/Application Support/ch.putzzentrale.schluessel/schluessel.sqlite
```

Beim ersten Start legt `DatabaseManager` diesen Pfad und alle Tabellen selbst an — keine manuelle Einrichtung nötig.

---

## 8. App starten

`⌘R` — beim ersten Start erscheint ein Systemdialog zur Freigabe der Erinnerungen-App.

---

## Backup / Datensicherung

Für ein manuelles Backup genügt es, die Datenbankdatei zu kopieren:

```bash
cp ~/Library/Application\ Support/ch.putzzentrale.schluessel/schluessel.sqlite ~/Desktop/backup_$(date +%Y%m%d).sqlite
```
