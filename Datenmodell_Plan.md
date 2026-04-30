# Datenmodell-Plan: Sprung von main auf Soll-Zustand

Stand: 30.04.2026 — abgenommen. Basis: Prozesslogik.md (mit den 7 Designentscheidungen aus Kapitel 0 und den nachgezogenen Verfeinerungen).

Ziel: in einem sauberen Wurf vom heutigen `main` (`f4d067c`) auf den vollen Soll-Zustand kommen — Vertragsende-Workflow, Audit-Felder, Storno, Prüfbedürftig-Marker, manuelle Standort-Übersteuerung (W11). Keine Wiederbelebung des dirty `quizzical-archimedes-3d7735` Worktrees.

---

## 1. Neue Felder

### `CDBewegung` (heute 12 Attribute → +10)

| Feld | Typ | Default | Zweck |
|---|---|---|---|
| `modifiziertVon` | String | `""` | Audit, gesetzt bei jeder Änderung |
| `modifiziertAm` | Date? | nil | Audit |
| `endgueltigeUebergabeAnKunde` | Bool | false | Vertragsende-Marker (W4/W5) |
| `storniert` | Bool | false | W10-Flag |
| `stornoBegruendung` | String? | nil | W10 Pflicht-Notiz |
| `storniertAm` | Date? | nil | W10 Audit |
| `storniertVon` | String? | nil | W10 Audit |
| `pruefbeduerftig` | Bool | false | Marker (gesetzt durch W11-Cascade) |
| `pruefbeduerftigGrund` | String? | nil | „Standort manuell übersteuert am …" |
| `pruefbeduerftigAm` | Date? | nil | Wann der Marker gesetzt wurde |

### `CDKunde` (heute 6 Attribute → +7)

| Feld | Typ | Default | Zweck |
|---|---|---|---|
| `schluesselZurueckgegebenAm` | Date? | nil | Vertragsende-Datum |
| `schluesselZurueckgegebenVon` | String? | nil | Vertragsende Audit |
| `standortManuellAm` | Date? | nil | **Trigger** für „manuell gesetzt" (nil ⇒ kein W11) |
| `standortManuellVon` | String? | nil | W11 Audit |
| `standortManuellNotiz` | String? | nil | W11 Pflicht-Notiz |
| `standortManuellTyp` | String? | nil | Enum-Wert: `beiRK / imBuero / beiStellv / beimKunde / unbekannt` |
| `standortManuellStellvRKId` | UUID? | nil | nur wenn `Typ = beiStellv` |

### `CDReinigungskraft`
Unverändert.

---

## 2. Migration

Alles **Lightweight**, weil nur neue **optionale** Attribute und Bools mit Default. Kein neues `xcdatamodeld`-Versions-Bundle nötig — es reicht ein **neuer Versions-Eintrag** in derselben `xcdatamodeld`-Datei (`v2`). CloudKit-kompatibel: keine Pflicht-Attribute, keine Beziehungs-Änderungen, keine Umbenennungen.

---

## 3. Swift-Structs (`Quellcode/Models/`)

- `Bewegung`: 10 neue Properties + neuer Computed `pruefbeduerftigOffen: Bool`. `BewegungStatus`-Enum bleibt; UI-Logik liest zusätzlich `pruefbeduerftig` und `storniert`.
- Neuer Enum `ManuellerStandortTyp: String` (5 Cases) statt String-Hantierung.
- `Kunde`: 7 neue Properties + Computed Helper `hatManuellenStandort: Bool`. Beziehungs-bezogene Helper (z.B. „letzte Vertragsende-Bewegung") liegen besser im AppViewModel.

---

## 4. Repository-Schicht

- `BewegungRepository`:
  - Mapping erweitern (alle neuen Felder)
  - Neue Methoden: `stornieren(id, begruendung, von)`, `pruefbeduerftigSetzen(id, grund)`, `pruefbeduerftigEntfernen(id)`
  - `aktualisieren` setzt automatisch `modifiziertVon/Am`
  - **Hard-Delete `loeschen` wird aus dem öffentlichen API entfernt** — bleibt als `internal`/Test-Helper bestehen, ist aus ViewModel/UI nicht mehr erreichbar
- `KundenRepository`:
  - Neue Methoden: `vertragBeenden(id, datum, notiz, von)`, `reaktivieren(id)`, `standortManuellSetzen(id, typ, stellvRKId, notiz, von)`, `hardLoeschen(id)`
  - `hardLoeschen` blockiert, wenn ≥1 Bewegung existiert

---

## 5. View-Folgearbeiten (eigene Commits, nicht im Schema-Commit)

- `BewegungErfassenView`: 4. Ablage „An Kunde", kontextabhängiges Pool-Label („Im Pool eingetragen" vs. „Im CRM ausgetragen")
- `SchluesselUebersichtView`: neue Karten `VertragBeendetKarte`, `ManuellGesetztKarte`; „Angenommen bei RK"-Modus (kursiv) wenn keine Bewegung existiert; Warnband bei `pruefbeduerftig`; Reaktivierungs-Banner mit W11-Direktverweis
- Neue Sheets: `VertragBeendenSheet`, `StandortManuellSetzenSheet`, `StornoSheet`
- `HistorieView` / `SchluesselbewegungenView`: Filter „Stornierte zeigen" (default off), durchgestrichene Darstellung; Filter „Prüfbedürftig"
- Bestätigungsdialoge für W4/W5/W6/W8/W10/W11 gemäss Tabelle in Prozesslogik.md Kapitel 7

---

## 6. Reihenfolge der Commits

1. **Schema-Migration** — alle Felder, Mapping, Repository-Methoden ohne Verhalten in der UI. Build und Tests grün, App funktional unverändert.
2. **Vertragsende W4/W5 + VertragBeendetKarte + Reaktivierung W6** (mit Banner, kein eigener W7).
3. **Audit `modifiziertVon/Am`** durchgängig in allen Mutationen aktiv.
4. **Storno W10** inkl. Sheet, Bestätigung, Filter, Anzeige.
5. **W11 manueller Standort** inkl. Sheet, Bestätigung, Cascade auf offene Bewegungen → prüfbedürftig, Anzeige.
6. **Validierungen** (Hakennummer 1–48, Kundennr-Eindeutigkeit, Pflichtnotizen scharf schalten).
7. **Bestätigungsdialoge** für die restlichen gefährlichen Aktionen (W8 Hard-Delete).
8. **Demo-Daten entfernen**, NULL-Start vorbereiten.

Schritt 1 ist Voraussetzung für alles. 2–8 in dieser Reihenfolge sinnvoll, aber technisch unabhängig — wenn etwas dazwischen scheitert, bleiben die vorherigen Commits stable.

---

## 7. Festgehaltene Detail-Entscheidungen

### a) Audit-Historie für W11
**Akzeptiert: keine Historie.** Ein zweites W11 für denselben Kunden überschreibt die `standortManuell*`-Felder. Nur der letzte manuelle Standort bleibt erhalten. Begründung: kein Over-Engineering, im 3-Personen-Büro mit ~200 Kunden kein realer Bedarf.

### b) Verhalten der `standortManuell*`-Felder bei späteren Bewegungen
**Felder bleiben stehen.** Anzeige-Logik vergleicht Datums: wenn die jüngste Bewegung nach `standortManuellAm` erstellt wurde, wird der manuelle Eintrag in der Anzeige ignoriert, bleibt aber als Audit am Kunde gespeichert. Begründung: nichts geht verloren.

### c) Hard-Delete von `CDBewegung`
**Verboten aus UI/ViewModel.** Storno (W10) ist die einzige offizielle Wegnahme. Die Repository-Methode bleibt internal für Tests/Migration, ist aber nicht mehr aufrufbar aus normalem App-Code.

---

## 8. Was nach Abschluss noch offen bleibt

- **CloudKit Sharing (CKShare)** — Phase 3, nicht Teil dieses Plans
- **Service-Layer-Refactoring** (PendenzService, StandortService) — kann später, sobald `AppViewModel` zu gross wird (heute 295 Zeilen, wird hier auf ~500–600 wachsen)
- **Reminder-Sync-Service** — getrennte Phase
- **4-Listen-Reminders** unter zhs@putzzentrale.ch — Phase 2 Schritt 3 nach Plan
