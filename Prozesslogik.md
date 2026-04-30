# Prozesslogik Putzzentrale-Schlüsselverwaltung

Stand: 30.04.2026 — **Soll-Zustand**. Kapitel „Abweichungen Ist vs. Soll" am Ende.

## 0. Zentrale Designentscheidungen

Festgehalten am 30.04.2026 nach Briefing-Abgleich. Diese 7 Entscheidungen sind die fachliche Basis für alle nachfolgenden Workflows.

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Drehscheibe | Bleibt fachliche Regel. Eine Pendenz darf mehrere physische Schritte zusammenfassen (z.B. Stellv→Büro→RK in einem Schliessen-Schritt). |
| 2 | Schlüssel/Kunde | 1:1. Schlüsselnummer = Kundennummer aus CRM. Keine n:m-Erweiterung geplant. |
| 3 | Standort manuell setzbar | Ja, mit Pflicht-Notiz und Audit-Eintrag. Erzeugt **keine** Bewegung, sondern markiert den Kunden mit Standort-Status „manuell gesetzt". |
| 4 | Berechtigungen | Keine Rollen. Silvia, Marina, PraktikantIn dürfen alles. Sicherheit ausschliesslich über Audit-Trail. |
| 5 | Stornierte Pendenzen | Bleiben in der Historie sichtbar (grau/durchgestrichen), sind aus dem Standard-Filter ausgeblendet. Hard-Delete bleibt verboten. |
| 6 | Erledigte wiederöffnen | **Nein.** Erledigte Bewegungen sind read-only/eingefroren. Korrekturen erfolgen über eine neue Bewegung, die den realen Stand wiederherstellt. |
| 7 | Leitprinzip | Operative Arbeitswahrheit. Schnelle Korrekturen erlaubt, aber jede Änderung erzeugt einen Audit-Eintrag — kein stillschweigendes Überschreiben. |

### Konsequenzen für die Logik

- Bewegungs-Lebenszyklus erweitert um Status **storniert** (siehe Kapitel 3).
- Schlüssel-Standorte erweitert um **manuell gesetzt** (siehe Kapitel 2).
- Neue Workflows: **W10 Storno**, **W11 manuelle Standort-Übersteuerung** (siehe Kapitel 4).
- Reaktivierungs-Lücke (siehe Kapitel 8 B) wird über W11 gelöst — Standort wird nach Reaktivierung explizit gesetzt, statt synthetische Bewegungen anzulegen.

---

## 1. Grundregeln

### Drehscheibe-Regel (heilig)
Schlüssel gehen **immer über das Büro**, nie direkt zwischen Personen:
- RK → Büro → Stellvertretung
- Stellvertretung → Büro → RK
- RK → Büro → Kunde (Vertragsende)

Verboten:
- RK → Stellvertretung direkt
- Stellvertretung → RK direkt
- RK → Kunde direkt

### Kunden-Schlüssel-Verhältnis
- 1 Kunde = 1 Schlüssel (Schlüsselnummer = Kundennummer aus CRM).
- Kein Schlüssel ohne Kunde, kein Kunde ohne Schlüssel-Kontext.
- Beim Anlegen eines neuen Kunden ist der Schlüssel implizit **bei der zugeteilten RK** (kein Erstkontakt-Erfassungs-Vorgang nötig).

### Audit-Trail
- Jede Bewegung trägt `erstelltVon/Am` und `modifiziertVon/Am`.
- Historie darf nie verloren gehen: Hard-Delete eines Kunden ist nur erlaubt, wenn 0 Bewegungen existieren.
- Vertragsende-Bewegungen (Marker) bleiben auch nach Reaktivierung erhalten.

---

## 2. Schlüssel-Standorte (6 mögliche Zustände)

| # | Standort                  | Bedingung im Datenmodell                                                |
|---|---------------------------|-------------------------------------------------------------------------|
| 1 | Bei zugeteilter RK         | Kunde aktiv, keine offene Bewegung, kein manueller Standort gesetzt      |
| 2 | Im Büro (Safe / Dossier)   | Offene Bewegung mit `bueroAblage` ≠ nil **und** `stellvertretungRKId` = nil |
| 3 | Bei Stellvertretung        | Offene Bewegung mit `stellvertretungRKId` ≠ nil **und** `bueroAblage` = nil |
| 4 | Beim Kunde (Vertrag beendet) | Kunde inaktiv, `kunde.schluesselZurueckgegebenAm` ≠ nil                  |
| 5 | Unbekannt / „Schlüssel nicht im System" | Kunde reaktiviert nach Vertragsende, ohne neue Bewegung und ohne manuell gesetzten Standort |
| 6 | Manuell gesetzt            | `kunde.standortManuellAm` ≠ nil — Standort wurde via W11 explizit gesetzt; übersteuert die Ableitung aus Bewegungen |

**Invariante**: `bueroAblage` und `stellvertretungRKId` sind **gegenseitig ausschliessend** — nie beide gleichzeitig gesetzt.

**Vorrangregel**: Sobald eine neue reguläre Bewegung erfasst wird (Status 2, 3 oder 4), übernimmt diese die Standort-Hoheit. Der manuell gesetzte Standort bleibt als Audit-Eintrag am Kunde erhalten, wirkt aber nicht mehr auf die Anzeige.

---

## 3. Bewegungs-Lebenszyklus

### Bewegung-Zustände
- **Offen**: `datumRueckgabe = nil`, `storniert = false`. Schlüssel ist im Büro oder bei Stellv.
- **Geschlossen (regulär)**: `datumRueckgabe ≠ nil`, `endgueltigeUebergabeAnKunde = false`. Schlüssel ist wieder bei zugeteilter RK. **Read-only / eingefroren** — kann nicht wieder geöffnet werden (Entscheidung 6). Korrekturen erfolgen über eine neue Bewegung.
- **Geschlossen (Vertragsende)**: `datumRueckgabe ≠ nil`, `endgueltigeUebergabeAnKunde = true`. Schlüssel ist beim Kunde, Kunde inaktiv. Ebenfalls read-only.
- **Storniert**: `storniert = true`. Pendenz wurde verworfen, hat keine Standort-Auswirkung. Bleibt mit Begründung in der Historie sichtbar, aus dem Standard-Filter ausgeblendet. Nur **offene** Pendenzen können storniert werden.

### Status-Berechnung (offene Bewegung)
- **Offen**: heute ≤ erwartete Rückgabe (oder keine erwartete Rückgabe gesetzt)
- **Überfällig**: heute > erwartete Rückgabe

### Marker auf offenen Bewegungen
- **Prüfbedürftig** (`pruefbeduerftig = true`, plus `pruefbeduerftigGrund`, `pruefbeduerftigAm`): die offene Pendenz steht im Verdacht, nicht mehr der Realität zu entsprechen. Wird automatisch gesetzt, wenn W11 (manueller Standort) ausgelöst wird, während diese Pendenz offen ist. Manuell setzbar ist der Marker nicht — er entsteht nur durch Logik-Konflikte. Auflösung: durch Storno (W10) oder durch eine neue, korrigierende Bewegung. Sobald die Bewegung geschlossen oder storniert wird, bleibt der Marker als Audit erhalten, hat aber keine Anzeige-Wirkung mehr.
- **Überfällig**: rein computed (siehe oben), kein gespeichertes Feld.

Marker und Status sind orthogonal: eine Bewegung kann gleichzeitig „offen + überfällig + prüfbedürftig" sein.

---

## 4. Workflows

### W1: Schlüssel einfordern (RK → Büro / Stellv / Kunde)
**Voraussetzung**: keine offene Bewegung für diesen Kunden, Kunde aktiv, RK zugeteilt.

**Auslöser**: Kunden-Detail → Button „Schlüssel einfordern"

**Eingabe**:
- Datum
- Grund (Ferien / Krankheit / Einzel-Termin)
- Erwartetes Rückgabedatum (optional)
- **Ablageort**, eines von:
  - **Safe** (mit Hakennummer 1–48, Pflichtfeld)
  - **Dossier** (mit Kürzel, Pflichtfeld)
  - **Stellvertretung** (RK aus Liste, Pflichtfeld)
  - **An Kunde** (Vertragsende, ohne weitere Felder — Bewegung wird sofort geschlossen, Kunde wird inaktiv)
- Pool-eingetragen (CRM-Pflichtfeld)
- Notizen (optional)

**Ergebnis**:
- Bei Safe/Dossier/Stellv: offene Bewegung angelegt
- Bei „An Kunde": Bewegung mit `datumRueckgabe = datumAbgang` und `endgueltigeUebergabeAnKunde = true`, Kunde inaktiv mit Vertragsende-Feldern

### W2: Schlüssel-Rückgabe (Büro/Stellv → zugeteilte RK)
**Voraussetzung**: offene Bewegung existiert.

**Auslöser**: Standort-Karte → Button „Zurückgegeben"

**Eingabe**: Rückgabedatum

**Ergebnis**: Bewegung geschlossen mit `datumRueckgabe`. Schlüssel ist nominell bei zugeteilter RK.

**Hinweis**: Bei Stellv→Büro→RK wird das in einem Schritt modelliert (Bewegung schliessen). Konzeptuell ist das „durchs Büro" — das wird nicht als zwei Bewegungen erfasst.

### W3: An Stellvertretung übergeben (Büro → Stellv)
**Voraussetzung**: offene Bewegung mit `bueroAblage ≠ nil` (Schlüssel im Büro), `stellvertretungRKId = nil`.

**Auslöser**: Standort-Karte → Button „An Stellvertretung"

**Eingabe**: RK-Auswahl

**Ergebnis**: Dieselbe Bewegung wird umgestellt:
- `stellvertretungRKId = neue RK`
- `bueroAblage = nil`
- `bueroAblageDetail = ""`

**Invariante bleibt**: nur eines von beiden Feldern ist gesetzt.

### W4: Vertrag beenden (Pfad 1, 2-Schritt)
**Voraussetzung**: Schlüssel ist im Büro (offene Bewegung mit `bueroAblage`).

**Auslöser**: Kunden-Detail-Menü → „Vertrag beenden…"

**Falls Schlüssel nicht im Büro**: Hinweis-Dialog „Bitte zuerst Schlüssel ins Büro einholen."

**Eingabe**: Übergabedatum + Notiz

**Ergebnis**:
- Bewegung geschlossen: `datumRueckgabe = uebergabedatum`, `endgueltigeUebergabeAnKunde = true`, Notiz angehängt
- Kunde: `aktiv = false`, `schluesselZurueckgegebenAm`, `schluesselZurueckgegebenVon`

### W5: Vertrag beenden (Pfad 2, direkt aus Einfordern)
Siehe W1, Ablageort „An Kunde".

### W6: Kunde reaktivieren
**Voraussetzung**: Kunde inaktiv mit `schluesselZurueckgegebenAm ≠ nil`.

**Auslöser**: Kunden-Detail-Menü → „Reaktivieren"

**Ergebnis**:
- `aktiv = true`
- Vertragsende-Felder am Kunde geleert
- Bewegungs-Eintrag mit `endgueltigeUebergabeAnKunde = true` bleibt erhalten (Audit)
- **Schlüssel-Status danach**: 5 (Unbekannt). Standort-Karte zeigt einen prominenten Hinweisbanner „Standort nach Reaktivierung manuell setzen" mit Direktverweis auf **W11**.
- Kein eigener Wiedereintritts-Workflow mehr (vormals W7) — der Wiedereintritt **ist** ein W11-Ereignis und wird als solches auditiert.

### W7: *(entfernt — durch W11 ersetzt)*
Die frühere Variante mit synthetischer „Wiedereintritts-Bewegung" oder stillem Zurückfallen auf „bei RK" ist entfallen. Der Wiedereintritt nach Reaktivierung läuft ausschliesslich über **W11** (manuelle Standort-Übersteuerung). Damit wird jeder Wiedereintritt zwingend als Audit-Ereignis erfasst.

### W8: Endgültig löschen (Hard-Delete)
**Voraussetzung**: Kunde hat **keine** Bewegungen.

**Auslöser**: Kunden-Detail-Menü → „Endgültig löschen…"

**Ergebnis**: Kunde wird aus DB entfernt. Falls Bewegungen existieren: Aktion blockiert mit Fehlermeldung.

### W9: Bewegung bearbeiten / löschen
- Offene Bewegung kann bearbeitet werden (Datum, Ablage, Notizen)
- Geschlossene Bewegung ist **read-only** (Entscheidung 6). Wirklich keine Notiz/Datum-Korrektur mehr — falsche Erledigungen werden über eine neue, korrigierende Bewegung ausgeglichen.
- Vertragsende-Bewegungen: ebenfalls read-only.
- Löschen einer Bewegung: verboten (Audit). Statt löschen → stornieren via W10 (nur bei offenen).

### W10: Pendenz stornieren
**Voraussetzung**: Bewegung ist offen (`datumRueckgabe = nil`, `storniert = false`).

**Auslöser**: Bewegungs-Detail / Historie → „Stornieren…"

**Eingabe**: Pflicht-Begründung (Notizfeld, nicht leer)

**Ergebnis**:
- `storniert = true`, `storniertAm = jetzt`, `storniertVon = aktueller Benutzer`, `stornoBegruendung = Eingabe`
- Apple-Erinnerung wird gelöscht (falls vorhanden)
- Standort des Kunden bleibt unverändert — es hat ja keine physische Bewegung stattgefunden
- Bewegung erscheint in der Historie als storniert (grau / durchgestrichen), aus Standard-Filter ausgeblendet

**Wichtig**: Storno ist **nicht** dasselbe wie eine erledigte Bewegung wieder öffnen — das ist nicht erlaubt (Entscheidung 6). W10 wirkt nur auf **offene** Pendenzen.

### W11: Schlüssel-Standort manuell setzen (Übersteuerung)
**Voraussetzung**: Kunde existiert. Funktioniert auch ohne RK-Zuteilung und nach Reaktivierung.

**Auslöser**: Kunden-Detail → „Standort manuell setzen…"

**Eingabe**:
- Ziel-Standort: Bei zugeteilter RK / Im Büro / Bei Stellvertretung / Beim Kunde / Unbekannt
- Bei „Bei Stellvertretung": RK-Auswahl
- Pflicht-Notiz: Begründung (z.B. „Schlüssel nach Reaktivierung beim Kunde gelassen")

**Bestätigung**: Modaler Bestätigungsdialog, listet zusätzlich offene Pendenzen auf, die durch diese Aktion als prüfbedürftig markiert werden (siehe unten).

**Ergebnis**:
- Audit-Felder am Kunde gesetzt: `standortManuellAm = jetzt`, `standortManuellVon = aktueller Benutzer`, `standortManuellNotiz = Eingabe`, plus Felder, die das gewählte Ziel speichern (genaue Felder klären wir im Code-Schritt)
- **Keine Bewegung** wird angelegt
- Standort-Karte zeigt den manuellen Standort mit Hinweisband „Manuell gesetzt am … von …"
- Sobald eine neue reguläre Bewegung erfasst wird, übernimmt diese die Standort-Hoheit; der manuelle Eintrag bleibt als Audit erhalten

**Verhalten bei offenen Pendenzen**: Existieren beim Auslösen offene Bewegungen für den Kunden (`datumRueckgabe = nil`, `storniert = false`), werden diese **automatisch als prüfbedürftig markiert** (`pruefbeduerftig = true`, `pruefbeduerftigGrund = "Standort manuell übersteuert am [Datum] von [Benutzer]"`, `pruefbeduerftigAm = jetzt`). Die Pendenzen bleiben formal offen, der User räumt sie nachträglich auf — entweder durch Storno (W10) oder durch eine neue, korrigierende Bewegung. So kann ein manueller Standort einer offenen Bewegung nie unsichtbar widersprechen.

**Anwendungsfälle**:
- Reaktivierung eines Kunden, dessen Schlüssel real noch beim Kunden ist (löst Lücke B aus Kapitel 8)
- Inventur — vergessener Schlüssel taucht auf
- Korrektur einer falsch abgeleiteten Standortannahme nach Datenchaos

---

## 5. Stellvertretungs-Bulk-Operation
**Auslöser**: RK-Detail → „Alle Stellvertretungs-Schlüssel zurück"

**Ergebnis**: Alle offenen Bewegungen mit dieser RK als Stellv werden geschlossen. Konzeptuell: Stellv → Büro → zugeteilte RK in einem Schritt.

---

## 6. Anzeige-Logik

### Standort-Karte im Kunden-Detail (Soll)
Reihenfolge der Prüfung (erste passende Regel gewinnt):

1. Wenn `kunde.schluesselZurueckgegebenAm ≠ nil` → **VertragBeendetKarte** (grau, Siegel-Icon, Datum, kein Aktions-Button)
2. Wenn `kunde.aktiv = false` ohne Vertragsende-Felder → **Altdaten-Hinweiskarte** „Kunde inaktiv — manuell klären" (Aktions-Button blockiert)
3. Wenn `kunde.standortManuellAm ≠ nil` und kein neueres Bewegungsereignis → **ManuellGesetztKarte** mit Hinweisband „Manuell gesetzt am [Datum] von [Benutzer] — [Notiz]". Aktion „Standort erneut setzen" via W11.
4. Wenn offene Bewegung existiert → **SchluesselUnterwegsKarte** mit Aktionen (An Stellv, Zurückgegeben, Bearbeiten, Stornieren). Falls die Bewegung `pruefbeduerftig = true` ist, zusätzlich gelbes Warnband mit dem Grund und der Aufforderung, sie zu stornieren oder durch neue Bewegung zu ersetzen.
5. Wenn der Kunde **noch nie eine Bewegung hatte** und `standortManuellAm = nil` → **SchluesselBeiRKKarte (angenommen)** — Label kursiv „Angenommen bei [RK]" statt fett, plus dezenter Hinweis „Standort abgeleitet aus Anlage". Aktionen: „Schlüssel einfordern" und „Standort manuell setzen…" (W11).
6. Wenn mindestens eine geschlossene Bewegung existiert und `standortManuellAm = nil` → **SchluesselBeiRKKarte** (verifiziert, normales fettes Label), Aktion „Schlüssel einfordern".
7. Sonst (keine RK zugeteilt) → Hinweis „Bitte erst RK zuteilen"

**Spezialfall Reaktivierung**: Solange `standortManuellAm = nil` und die letzte Bewegung eine Vertragsende-Bewegung war, zeigt die Karte zusätzlich ein rotes Banner „Standort nach Reaktivierung manuell setzen" mit Direktverweis auf W11.

### Kunden-Listen-Zeile (Status-Punkt-Farbe)
- grau: Vertrag beendet
- rot: offene Bewegung überfällig **oder** prüfbedürftig
- orange: offene Bewegung
- grün: Normalzustand (Schlüssel bei RK, verifiziert oder angenommen)

### Kunden-Listen-Filter
- Default: nur aktive Kunden
- Toggle „Inaktive zeigen": auch Vertragsende-Kunden anzeigen
- Toggle „Im Umlauf": nur Kunden mit Schlüssel nicht bei RK
- Toggle „Prüfbedürftig": nur Kunden mit mindestens einer prüfbedürftigen offenen Bewegung

### Historie / Bewegungsliste
- Default-Filter: stornierte Bewegungen ausgeblendet
- Toggle „Stornierte zeigen": stornierte Bewegungen werden grau / durchgestrichen mit Stornogrund eingeblendet
- Stornierte Bewegungen sind nie editierbar

---

## 7. Validierungs-Regeln (Soll)

### Feld-Validierung

| Feld                          | Regel                                                    | Aktuell erzwungen? |
|-------------------------------|----------------------------------------------------------|--------------------|
| Kundennummer                  | Pflicht, eindeutig                                       | Pflicht ✅, Eindeutigkeit ❌ |
| Kundenname                    | Pflicht                                                  | ✅                 |
| Hakennummer (Safe)            | Pflicht bei Safe, numerisch, 1–48                        | ❌                 |
| Dossier-Kürzel                | Pflicht bei Dossier                                      | ❌                 |
| Stellvertretungs-RK           | Pflicht bei Stellv-Wahl                                  | ✅                 |
| CRM-Sync-Feld (siehe unten)   | Pflicht                                                  | ✅                 |
| Erwartetes Rückgabedatum      | Optional, aber wenn gesetzt: ≥ datumAbgang               | ✅                 |
| Stornogrund (W10)             | Pflicht, nicht leer/whitespace                           | ❌ (W10 neu)       |
| W11-Notiz                     | Pflicht, nicht leer/whitespace                           | ❌ (W11 neu)       |
| Vertragsende-Notiz (W4/W5)    | Pflicht, nicht leer/whitespace                           | ❌                 |

### Kontextabhängige Beschriftung des CRM-Sync-Felds
Dasselbe gespeicherte Boolean (`poolEingetragen`) hat unterschiedliche Bedeutungen je nach Workflow:
- W1 mit Ablage Safe / Dossier / Stellvertretung → Label **„Im Pool eingetragen"** (Schlüssel kommt rein)
- W1 mit Ablage „An Kunde" und W4 (Vertragsende) → Label **„Im CRM ausgetragen"** (Schlüssel verlässt das System)

Der Datenpunkt selbst bleibt ein einziges Feld, das semantisch „CRM-Sync erfolgt" bedeutet — die UI-Beschriftung ist kontextabhängig. Damit ist Lücke K aufgelöst.

### Bestätigungsdialog-Pflicht (gefährliche Aktionen)
Folgende Aktionen erfordern einen modalen Bestätigungsdialog mit klarer Ja/Nein-Wahl, **bevor** die Aktion ausgeführt wird:

| Aktion                                | Bestätigung | Pflichtnotiz | Zusätzlich im Dialog |
|---------------------------------------|-------------|--------------|----------------------|
| W4/W5 Vertrag beenden                 | ✅          | ✅            | Übergabedatum, Hinweis „Aktion macht Kunde inaktiv" |
| W10 Pendenz stornieren                | ✅          | ✅            | Hinweis „Storno ist endgültig — Pendenz lebt nur noch in der Historie" |
| W11 Standort manuell setzen           | ✅          | ✅            | Liste der offenen Pendenzen, die dadurch prüfbedürftig werden |
| W8 Hard-Delete Kunde / RK             | ✅          | —            | Hinweis „Endgültig, nur möglich weil 0 Bewegungen" |
| W6 Kunde reaktivieren                 | ✅          | —            | Hinweis „Standort danach manuell setzen (W11)" |

Reine Datenkorrekturen an offenen Bewegungen (W9 Bearbeiten) brauchen keine zusätzliche Bestätigung — `modifiziertVon/Am` reicht als Audit.

---

## 8. Abweichungen Ist vs. Soll (gefundene Lücken)

### A) Stellvertretungs-Übergabe (W3) bricht die Invariante
**Problem**: `AppViewModel.stellvertretungSetzen` setzt nur `stellvertretungRKId` neu, **lässt `bueroAblage` aber stehen**. Damit sind beide Felder gesetzt — verletzt die Invariante aus Kapitel 2.

**Fundstelle**: [AppViewModel.swift:257](Quellcode/ViewModels/AppViewModel.swift:257)

**Symptom**: Daten-Inkonsistenz. UI priorisiert `stellvertretungRKId`, also sieht User nichts — aber `aufenthaltsText`/Historie könnten je nach View widersprüchliche Anzeigen liefern.

**Fix**: In `stellvertretungSetzen` zusätzlich `bueroAblage = nil`, `bueroAblageDetail = ""` setzen.

### B) Reaktivierung lässt Schlüssel-Status undefiniert (W6/W7)
**Problem**: Beim Reaktivieren werden die Vertragsende-Felder am Kunde gelöscht, `aktiv = true` gesetzt. Standort-Karte fällt damit auf „Bei zugeteilter RK" zurück — aber **der Schlüssel ist real beim Kunden**, nicht bei der RK.

**Fundstelle**: [AppViewModel.swift:113](Quellcode/ViewModels/AppViewModel.swift:113), [SchluesselUebersichtView.swift:262](Quellcode/Views/SchluesselUebersichtView.swift:262)

**Symptom**: Falsche Anzeige nach Reaktivierung.

**Fix (entschieden 30.04.2026)**: Über **W11 manuelle Standort-Übersteuerung**. Nach Reaktivierung kann der Benutzer den realen Standort explizit setzen. Wir erzwingen das nicht hart — die Standort-Karte zeigt aber einen Hinweis „Standort nach Reaktivierung manuell prüfen", solange `standortManuellAm` nicht gesetzt ist und die letzte Bewegung eine Vertragsende-Bewegung war.

### C) Standort-Karte für Altdaten-Inaktive (vor Vertragsende-Workflow)
**Problem**: Kunden, die früher per (jetzt entferntem) „Inaktiv setzen" inaktiv gesetzt wurden, haben `aktiv = false` aber keine Vertragsende-Felder. Standort-Karte zeigt fälschlich „Bei [RK]" mit Aktions-Button.

**Fundstelle**: [SchluesselUebersichtView.swift:262-273](Quellcode/Views/SchluesselUebersichtView.swift:262)

**Symptom**: Genau dein Befund mit „Frey, Nicole".

**Fix**: Anzeige-Logik erweitern (Punkt 2 der Standort-Karten-Regel oben). Aktions-Button blocken bei `aktiv = false`.

### D) Initialer Schlüssel-Eintritt nicht erfasst (W0 fehlt)
**Problem**: Neuer Kunde wird angelegt → Schlüssel ist sofort „bei zugeteilter RK" ohne Bewegungs-Eintrag. Kein Audit-Trail für den Erstkontakt (wann der Schlüssel ins System kam, wer ihn überreicht hat).

**Fundstelle**: konzeptionell, [AppViewModel.swift:96](Quellcode/ViewModels/AppViewModel.swift:96)

**Symptom**: Audit-Lücke — kein „Wann ist der Schlüssel zu uns gekommen?".

**Fix-Optionen**:
- Eintrags-Bewegung beim Kunde-Anlegen erzwingen (Datum + ggf. Ablage)
- Akzeptieren als „angenommen ab Anlage-Datum"

### E) Hakennummern-Validierung fehlt
**Problem**: Eingabefeld „Hakennr. (1–48)" akzeptiert beliebige Strings.

**Fundstelle**: [BewegungErfassenView.swift](Quellcode/Views/BewegungErfassenView.swift) — `TextField("Haken-Nr. (1–48)", text: $hakenNr)`

**Fix**: Numerische Eingabe + Range-Check 1–48 + Pflichtfeld bei Ablage Safe.

### F) Eindeutigkeit der Kundennummer fehlt
**Problem**: Zwei Kunden mit Nummer „1042" können angelegt werden.

**Fix**: Vor dem Speichern prüfen, ob Nummer bereits existiert (case-insensitive, getrimmt).

### G) RK-Hard-Delete ohne Audit-Schutz
**Problem**: Eine RK kann gelöscht werden, auch wenn sie in geschlossenen Bewegungen oder als zugeteilte RK referenziert ist. Cascade-Rule auf `Nullify` — Bewegungs-Historie verliert RK-Namen.

**Fundstelle**: [ReinigungskraftRepository.swift:32](Quellcode/Repositories/ReinigungskraftRepository.swift:32)

**Fix**: Analog zu Kunden — Soft-Delete via `aktiv = false`, Hard-Delete nur ohne Bewegungs-Referenzen.

### H) Vertragsende-Bewegung im Edit-Modus
**Problem**: User kann eine Vertragsende-Bewegung editieren und auf einen normalen Ablageort umstellen — aber `kunde.aktiv` und `schluesselZurueckgegebenAm` werden dann nicht zurückgesetzt. Asymmetrie.

**Fundstelle**: [BewegungErfassenView.swift](Quellcode/Views/BewegungErfassenView.swift) — `speichern`

**Fix**: Entweder Edit-Modus für Vertragsende-Bewegungen sperren (read-only), oder bei Umstellung nachfragen, ob Kunde reaktiviert werden soll.

### I) `aufenthaltsText` ignoriert Stellvertretung
**Problem**: `Bewegung.aufenthaltsText` schaut nur auf `bueroAblage`. Wenn beides gesetzt wäre (siehe A), liefert es widersprüchliche Anzeige zur UI.

**Fundstelle**: [Bewegung.swift:85](Quellcode/Models/Bewegung.swift:85)

**Fix**: Mit (A) zusammen — wenn Invariante hält, kein Problem.

### J) Demo-Daten erzeugen Inkonsistenzen
**Problem**: Demo-Daten generieren beliebige Kombinationen, nicht garantiert konsistent zur Soll-Logik (z.B. Stellvertretung gesetzt mit Büro-Ablage).

**Fix**: Demo-Daten ohnehin laut Phase 2 Schritt 6 entfernen.

### K) „Im Pool eingetragen" als Pflichtfeld auch bei Vertragsende
**Problem**: Bei Ablage „An Kunde" muss aktuell trotzdem „Im Pool eingetragen" abgehakt werden. Semantisch fragwürdig (der Schlüssel kommt aus dem Pool raus, nicht rein).

**Fix (entschieden 30.04.2026)**: Kontextabhängiges Label, dasselbe gespeicherte Feld. Bei Ablage Safe/Dossier/Stellv → „Im Pool eingetragen", bei Vertragsende-Pfaden → „Im CRM ausgetragen". Pflicht bleibt — der CRM-Sync ist in beide Richtungen wichtig. Siehe Kapitel 7.

---

## 9. Was als nächstes angegangen werden sollte

Nach Abnahme dieser Doku — Reihenfolge nach Schmerz/Aufwand:

1. **A** (Stellvertretungs-Invariante) — kleiner Fix, aber Daten-Konsistenz
2. **C** (Anzeige für Altdaten-Inaktive) — kleiner UI-Fix, beseitigt deinen Befund
3. **B** (Reaktivierungs-Lücke) — Workflow-Frage, mittel
4. **E + F** (Validierung) — Audit-Punkt 3, klarer Scope
5. **G** (RK-Lösch-Schutz) — analog zu Kunden, klein
6. **H** (Edit-Vertragsende) — Detail
7. **I** (`aufenthaltsText`) — fällt mit A weg
8. **D** (Initial-Eintritt) — Architekturfrage, später
9. **J** (Demo-Daten) — Phase 2 Schritt 6
10. **K** (Pool-Pflichtfeld) — Detail, später
