import Foundation

// Liest CSV-Stammdaten ein und liefert ein Vorschau-Ergebnis zurück.
// Erwartetes Format: UTF-8, Komma-getrennt, Werte mit Komma in doppelten Anführungszeichen.
// Keine Schreibzugriffe auf die DB – das übernimmt das ViewModel nach Bestätigung.
enum StammdatenImporter {

    // MARK: - Public API

    static func ladePF(url: URL, bestehende: [Reinigungskraft]) throws -> ImportErgebnis<Reinigungskraft> {
        let zeilen = try ladeCSVZeilen(url: url)
        guard zeilen.count > 1 else {
            throw CSVImportError.parseFehler(zeile: 0, grund: "Datei enthält keine Datenzeilen.")
        }
        let header = zeilen[0]
        guard header.contains("Name") else {
            throw CSVImportError.spaltenFehlen(erwartet: ["Name"], gefunden: header)
        }

        // Vergleich auf Kleinschreibung, damit "Müller" und "müller" als Duplikat gelten.
        let bestehendeNamen = Set(bestehende.map { $0.name.lowercased() })
        var gesehen = Set<String>()
        var ergebnis = ImportErgebnis<Reinigungskraft>()

        for (idx, werte) in zeilen.dropFirst().enumerated() {
            let zeilennr = idx + 2
            let dict = zeileZuDict(header: header, werte: werte)

            let name = dict["Name"]?.trimmingCharacters(in: .whitespaces) ?? ""
            if name.isEmpty {
                ergebnis.warnungen.append("Zeile \(zeilennr): Name fehlt – übersprungen")
                continue
            }

            var pf = Reinigungskraft()
            pf.name    = name
            pf.strasse = dict["Strasse"] ?? ""
            pf.plz     = dict["PLZ"] ?? ""
            pf.ort     = dict["Ort"] ?? ""
            pf.telefon = dict["Telefon"] ?? ""
            pf.mobil   = dict["Mobil"] ?? ""
            pf.aktiv   = true

            let key = name.lowercased()
            if bestehendeNamen.contains(key) {
                ergebnis.uebersprungen.append((pf, "Name bereits in DB"))
                continue
            }
            if gesehen.contains(key) {
                ergebnis.uebersprungen.append((pf, "Doppelter Name in CSV"))
                continue
            }
            gesehen.insert(key)
            ergebnis.neue.append(pf)
        }
        return ergebnis
    }

    static func ladeKD(url: URL, bestehende: [Kunde]) throws -> ImportErgebnis<Kunde> {
        let zeilen = try ladeCSVZeilen(url: url)
        guard zeilen.count > 1 else {
            throw CSVImportError.parseFehler(zeile: 0, grund: "Datei enthält keine Datenzeilen.")
        }
        let header = zeilen[0]
        let pflicht = ["ID", "Name"]
        for sp in pflicht where !header.contains(sp) {
            throw CSVImportError.spaltenFehlen(erwartet: pflicht, gefunden: header)
        }

        let bestehendeNummern = Set(bestehende.map { $0.kundennummer })
        var gesehen = Set<String>()
        var ergebnis = ImportErgebnis<Kunde>()

        for (idx, werte) in zeilen.dropFirst().enumerated() {
            let zeilennr = idx + 2
            let dict = zeileZuDict(header: header, werte: werte)

            let kdnr = dict["ID"]?.trimmingCharacters(in: .whitespaces) ?? ""
            let name = dict["Name"]?.trimmingCharacters(in: .whitespaces) ?? ""

            if kdnr.isEmpty {
                ergebnis.warnungen.append("Zeile \(zeilennr): KD-Nr fehlt – übersprungen")
                continue
            }
            if name.isEmpty {
                ergebnis.warnungen.append("Zeile \(zeilennr) (KD-Nr \(kdnr)): Name fehlt – übersprungen")
                continue
            }

            var k = Kunde()
            k.kundennummer   = kdnr
            k.name           = name
            k.firma          = dict["Firma"] ?? ""
            k.strasse        = dict["Strasse"] ?? ""
            k.plz            = dict["PLZ"] ?? ""
            k.wohnort        = dict["Ort"] ?? ""
            k.telefon        = dict["Telefon"] ?? ""
            k.mobil          = dict["Mobil"] ?? ""
            k.email          = dict["E-Mail"] ?? ""
            k.auftragsnummer = dict["Auftrag"] ?? ""
            k.aktiv          = true

            if bestehendeNummern.contains(kdnr) {
                ergebnis.uebersprungen.append((k, "KD-Nr bereits in DB"))
                continue
            }
            if gesehen.contains(kdnr) {
                ergebnis.uebersprungen.append((k, "Doppelte KD-Nr in CSV"))
                continue
            }
            gesehen.insert(kdnr)
            ergebnis.neue.append(k)
        }
        return ergebnis
    }

    // MARK: - CSV-Parser

    // Liest die Datei und liefert pro Zeile ein Array von Spalten.
    // Unterstützt: Komma-Trennung, Werte mit Komma in "…", doppelte "" als Escape.
    private static func ladeCSVZeilen(url: URL) throws -> [[String]] {
        guard let roh = try? String(contentsOf: url, encoding: .utf8) else {
            throw CSVImportError.dateiNichtLesbar
        }
        // Swift behandelt CRLF als einen einzelnen Grapheme-Cluster – beim Iterieren
        // mit String.Index sehen wir weder \r noch \n einzeln. Daher Zeilenende
        // vorher auf reines \n normalisieren.
        let inhalt = roh
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")

        var zeilen: [[String]] = []
        var aktuelleZeile: [String] = []
        var feld = ""
        var inQuote = false
        var i = inhalt.startIndex

        while i < inhalt.endIndex {
            let c = inhalt[i]

            if inQuote {
                if c == "\"" {
                    let next = inhalt.index(after: i)
                    if next < inhalt.endIndex, inhalt[next] == "\"" {
                        feld.append("\"")
                        i = next
                    } else {
                        inQuote = false
                    }
                } else {
                    feld.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuote = true
                case ",":
                    aktuelleZeile.append(feld)
                    feld = ""
                case "\r":
                    break
                case "\n":
                    aktuelleZeile.append(feld)
                    if !aktuelleZeile.allSatisfy({ $0.isEmpty }) {
                        zeilen.append(aktuelleZeile)
                    }
                    aktuelleZeile = []
                    feld = ""
                default:
                    feld.append(c)
                }
            }
            i = inhalt.index(after: i)
        }

        // Letzte Zeile (ohne abschliessendes Newline)
        if !feld.isEmpty || !aktuelleZeile.isEmpty {
            aktuelleZeile.append(feld)
            if !aktuelleZeile.allSatisfy({ $0.isEmpty }) {
                zeilen.append(aktuelleZeile)
            }
        }
        return zeilen
    }

    private static func zeileZuDict(header: [String], werte: [String]) -> [String: String] {
        var dict: [String: String] = [:]
        for (i, sp) in header.enumerated() where i < werte.count {
            dict[sp] = werte[i].trimmingCharacters(in: .whitespaces)
        }
        return dict
    }
}

// MARK: - Hilfstypen

struct ImportErgebnis<T>: Identifiable {
    let id = UUID()
    var neue: [T] = []
    var uebersprungen: [(T, String)] = []   // (Datensatz, Grund)
    var warnungen: [String] = []
}

enum CSVImportError: Error, LocalizedError {
    case dateiNichtLesbar
    case spaltenFehlen(erwartet: [String], gefunden: [String])
    case parseFehler(zeile: Int, grund: String)

    var errorDescription: String? {
        switch self {
        case .dateiNichtLesbar:
            return "Datei konnte nicht gelesen werden."
        case .spaltenFehlen(let erwartet, let gefunden):
            return "Erwartete Spalten: \(erwartet.joined(separator: ", ")). Gefunden: \(gefunden.joined(separator: ", "))."
        case .parseFehler(let zeile, let grund):
            return "Zeile \(zeile): \(grund)"
        }
    }
}
