# Briefing für Claude: Neuausrichtung Schlüsselverwaltungs-App

## Ausgangslage

Wir betreiben ein Hauptsystem/CRM, das die „Mutter aller Daten“ ist. Dieses CRM kann technisch nicht angebunden oder automatisiert ausgelesen werden. Eigentlich sollten dort alle Schlüsselbewegungen manuell eingetragen werden, was in der Praxis aber nicht immer zuverlässig geschieht.

Die neue App soll das CRM nicht ersetzen und nicht ab Tag 1 eine vollständige, historische Schlüssel-Inventarisierung sein. Sie soll eine operative Pendenzen- und Bewegungssteuerung für Schlüsselbewegungen sein.

Heute wird dies über Excel plus manuelle Kalendereinträge gelöst. Das ist fehleranfällig, unzuverlässig und für das Büro schwer steuerbar.

## Hauptziel der App

Die App beantwortet primär:

> Wer im Büro muss wann was mit welchem Schlüssel tun?

Der Hauptfokus ist also nicht „vollständiger physischer Standort aller Schlüssel ab Tag 1“, sondern:

- offene Schlüsselbewegungen erfassen
- Pendenzen steuern
- Fälligkeiten und Erinnerungen verwalten
- Büroaufgaben sichtbar machen
- Bewegungen nachvollziehbar erledigen, verschieben, korrigieren oder stornieren
- Apple-Erinnerungen integrieren
- Excel/Kalender als operative Steuerung ablösen

## Startzustand

Die App startet mit NULL Daten.

Ablauf beim Start:

1. Bestehende Reinigungskräfte/RK werden in den Stammdaten erfasst.
2. Bestehende offene/pendente Schlüsselbewegungen inkl. Kunden werden aus der Excel-Liste übernommen.
3. Danach wächst die Datenbank kontinuierlich durch neue Bewegungen.

Es gibt keine vollständige Migration der historischen CRM-Daten.

## Konsequenz für die Prozesslogik

Die App darf am Anfang nicht voraussetzen, dass der aktuelle Standort jedes Schlüssels bekannt oder vollständig korrekt ist.

Der Standort eines Schlüssels ergibt sich erst über die Zeit aus:

- erfassten Bewegungen
- erledigten Pendenzen
- manuellen Korrekturen
- nachträglichen Übersteuerungen

Daher müssen Zustände unterschieden werden:

- bekannt / verifiziert
- aus Bewegungen abgeleitet
- unbekannt / nicht verifiziert
- manuell korrigiert
- widersprüchlich / prüfbedürftig

## Zentrales fachliches Objekt

Nicht der Kunde ist das zentrale Objekt, sondern die Schlüsselbewegung/Pendenz.

Kunde und Schlüssel sind Stammdaten bzw. Bezugsobjekte.

Zentrale Entität:

> Bewegung / Pendenz

Diese hat mindestens:

- Kunde
- Schlüsselbezug
- Bewegungstyp
- von / nach
- verantwortliche Person oder Stelle
- Fälligkeit
- Status: geplant, offen, fällig, überfällig, erledigt, storniert, korrigiert
- Notiz/Grund
- Erinnerungs-ID, falls Apple-Erinnerung erzeugt wurde
- Erstellungsdatum
- Erledigungsdatum
- Änderungs-/Audit-Informationen

## Wichtiges Realitätsprinzip

Menschen machen Fehler.

Einträge werden vergessen, falsch erfasst oder nachträglich geändert. Deshalb darf die App keine starre, perfekte Prozessmaschine sein.

Die App muss jederzeit erlauben:

- Bewegungen zu korrigieren
- Zustände manuell zu übersteuern
- Pendenzen zu verschieben
- Pendenzen zu stornieren
- versehentlich erledigte Bewegungen wieder zu öffnen
- Standortannahmen zu korrigieren
- Notizen/Begründungen zu erfassen

Jede Korrektur sollte auditierbar sein, also nicht stillschweigend alte Daten überschreiben.

## Neue Leitregel

> Die App führt eine operative Arbeitswahrheit, keine absolute historische Wahrheit.

Diese operative Wahrheit muss korrigierbar, nachvollziehbar und für das Büro handlungsorientiert sein.

## Standortlogik

Der aktuelle physische Standort eines Schlüssels ist sekundär, aber nützlich.

Er sollte nicht als immer sichere Wahrheit dargestellt werden, sondern mit Vertrauensstatus:

- unbekannt
- vermutlich bei RK
- im Büro
- bei Stellvertretung
- beim Kunden
- manuell gesetzt
- widersprüchlich / prüfen

Wenn Standortdaten aus Bewegungen abgeleitet werden, muss klar sein, ob sie verifiziert oder nur plausibel sind.

## Pendenzlogik

Die wichtigste Logik ist der Lebenszyklus einer Pendenz:

1. geplant / erfasst
2. offen
3. fällig
4. überfällig
5. erledigt
6. storniert oder korrigiert

Bei jeder Änderung muss geprüft werden:

- Gibt es eine Apple-Erinnerung?
- Muss sie erstellt, aktualisiert, erledigt oder gelöscht werden?
- Hat die Änderung Auswirkungen auf andere offene Pendenzen desselben Kunden/Schlüssels?
- Entsteht ein widersprüchlicher Standort?
- Muss der Schlüsselstatus auf „prüfen“ gesetzt werden?

## Korrektur-/Übersteuerungslogik

Es braucht einen klaren Workflow für manuelle Korrekturen.

Beispiele:

### Fall 1: Bewegung vergessen
Ein Schlüssel wurde physisch bereits übergeben, aber nicht in der App erledigt.

Erwartung:
- Pendenz kann nachträglich als erledigt markiert werden.
- Erledigungsdatum kann ggf. angepasst werden.
- Standort wird entsprechend aktualisiert.
- Apple-Erinnerung wird erledigt.
- Audit/Notiz hält fest, dass es nacherfasst wurde.

### Fall 2: Bewegung falsch erfasst
Eine Pendenz wurde mit falscher RK oder falschem Ziel erfasst.

Erwartung:
- Pendenz kann korrigiert werden.
- Änderung wird historisiert.
- Apple-Erinnerung wird aktualisiert.
- Abgeleiteter Standort wird neu bewertet.

### Fall 3: Standort stimmt nicht
Der angenommene Standort ist falsch.

Erwartung:
- Standort kann manuell übersteuert werden.
- Grund/Notiz kann erfasst werden.
- Offene Pendenzen werden auf Plausibilität geprüft.
- Falls nötig werden Pendenzen als prüfbedürftig markiert.

### Fall 4: Pendenz ist hinfällig
Eine geplante Bewegung findet nicht mehr statt.

Erwartung:
- Pendenz kann storniert werden.
- Apple-Erinnerung wird gelöscht oder erledigt.
- Standort bleibt unverändert, sofern keine Bewegung stattgefunden hat.
- Storno-Grund wird dokumentiert.

## Bewertung bisheriger Logik

Die bisherige Betrachtung „Kunde hat genau einen Schlüssel und dieser Schlüssel hat immer einen exakten Zustand“ ist für dieses Projekt zu streng.

Richtiger ist:

> Eine Bewegung/Pendenz ist exakt steuerbar. Der Schlüsselstandort ist ein daraus abgeleiteter und korrigierbarer Arbeitsstand.

## Einschätzung zum bestehenden Code

Der bestehende Code muss wahrscheinlich nicht komplett gedroppt werden, sofern folgende Teile bereits vorhanden und brauchbar sind:

- SwiftUI-Grundstruktur
- Core-Data-Modell
- Kunden/RK-Stammdaten
- Bewegungs-Views
- einfache Status-/Fälligkeitslogik
- Apple-Erinnerungsintegration
- Grundnavigation

Aber die fachliche Mitte muss neu ausgerichtet werden.

Nicht weiter Flickwerk an einzelnen Symptomen machen. Stattdessen ein Refactoring mit klarem Zielmodell:

1. Bewegung/Pendenz als zentrale Entität festlegen
2. Statusmodell für Pendenzen sauber definieren
3. Standort nur als ableitbaren/korrigierbaren Zustand behandeln
4. Korrektur- und Storno-Workflows ergänzen
5. Audit/Notizen einführen
6. Apple-Erinnerungen konsequent an Pendenzstatus koppeln
7. Tests entlang realer Büroprozesse schreiben, nicht entlang einer idealisierten Schlüssel-Inventarlogik

## Empfohlene technische Prioritäten

### Priorität 1: Datenmodell klären

Benötigt werden wahrscheinlich:

- Kunde
- Reinigungskraft
- Schlüssel / oder Schlüsselbezug pro Kunde
- Bewegung/Pendenz
- Korrektur-/Audit-Ereignis
- optional StandortSnapshot oder berechneter Standort

### Priorität 2: Statusmodell definieren

Pendenzstatus:

- draft / geplant
- offen
- fällig
- überfällig
- erledigt
- storniert
- prüfbedürftig
- korrigiert

Schlüsselstandortstatus:

- unbekannt
- abgeleitet
- verifiziert
- manuell gesetzt
- widersprüchlich

### Priorität 3: Services zentralisieren

Nicht die Views sollen Geschäftslogik entscheiden.

Empfohlen:

- PendenzService
- StandortService
- ReminderSyncService
- AuditService
- ValidationService

### Priorität 4: Tests neu ausrichten

Tests sollten realistische Szenarien prüfen:

- neue offene Pendenz erfassen
- Pendenz wird fällig/überfällig
- Pendenz erledigen aktualisiert Standort und Erinnerung
- Pendenz stornieren verändert Standort nicht
- vergessene Bewegung nacherfassen
- falsche Bewegung korrigieren
- Standort manuell übersteuern
- offene Pendenzen bei Korrektur plausibilisieren
- Kunde existiert ohne bekannten Standort
- App startet mit NULL Historie

## Offene fachliche Entscheidungen

Bitte klären:

1. Muss jede Bewegung zwingend über das Büro laufen, oder dürfen zusammengefasste Schritte wie „RK → Büro → Stellvertretung“ in einer Pendenz dokumentiert werden?
2. Gibt es pro Kunde genau einen Schlüssel, oder mehrere Schlüssel/Sets?
3. Soll ein Standort manuell direkt gesetzt werden dürfen, auch wenn es keine Bewegung gibt?
4. Welche Korrekturen sollen normale Bürobenutzer machen dürfen, und welche nur Admins?
5. Soll eine stornierte Pendenz sichtbar bleiben?
6. Soll eine erledigte Pendenz wieder geöffnet werden können?
7. Was ist wichtiger: perfekte Historie oder schnelle operative Korrektur?

## Zielbild

Die App soll nicht versuchen, ein perfektes CRM oder Inventarsystem zu sein.

Sie soll ein robustes, fehlertolerantes Büro-Werkzeug sein, das Schlüsselbewegungen sichtbar, steuerbar, erinnerbar und korrigierbar macht.

Kurzform:

> Pendenzen steuern. Bewegungen dokumentieren. Standort ableiten. Fehler korrigierbar machen. Historie nachvollziehbar halten.
