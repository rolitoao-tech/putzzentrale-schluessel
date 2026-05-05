import SwiftUI
import UniformTypeIdentifiers

enum Navigationsbereich: String, Hashable {
    case uebersicht           = "Übersicht"
    case schluesselbewegungen = "Schlüsselbewegungen"
    case historie             = "Historie"
    case kunden               = "KD"
    case reinigungskraefte    = "PF"
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var bereich: Navigationsbereich? = .uebersicht
    @State private var ausgewaehlterKunde: Kunde?
    @State private var ausgewaehlteRK: Reinigungskraft?
    @State private var ausgewaehlteBewegung: Bewegung?
    @State private var rkFokus: RKFokus?
    @State private var spaltenSichtbarkeit: NavigationSplitViewVisibility = .all

    // Import-Status: ein gemeinsamer File-Picker, Typ-Schalter pro Aufruf.
    enum ImportTyp { case pf, kd }
    @State private var zeigeFilePicker = false
    @State private var importTyp: ImportTyp = .pf
    @State private var importPFErgebnis: ImportErgebnis<Reinigungskraft>?
    @State private var importKDErgebnis: ImportErgebnis<Kunde>?
    @State private var importFehler: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $spaltenSichtbarkeit) {
            seitenleiste
                .navigationSplitViewColumnWidth(min: 210, ideal: 210, max: 210)
        } content: {
            inhaltsSpalte
                .navigationSplitViewColumnWidth(min: 260, ideal: 360, max: 480)
        } detail: {
            detailSpalte
        }
        .environmentObject(vm)
        .onReceive(NotificationCenter.default.publisher(for: .importPFStarten)) { _ in
            importTyp = .pf
            zeigeFilePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .importKDStarten)) { _ in
            importTyp = .kd
            zeigeFilePicker = true
        }
        .fileImporter(isPresented: $zeigeFilePicker,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            switch importTyp {
            case .pf: verarbeitePFAuswahl(result)
            case .kd: verarbeiteKDAuswahl(result)
            }
        }
        .sheet(item: $importPFErgebnis) { ergebnis in
            ImportVorschauView(
                titel: "PF-Import: Vorschau",
                ergebnis: ergebnis,
                zeileBeschreibung: { pf in
                    var teile = [pf.name]
                    if !pf.ort.isEmpty { teile.append(pf.ort) }
                    if !pf.mobil.isEmpty { teile.append(pf.mobil) }
                    return teile.joined(separator: " · ")
                },
                onImport: { vm.pfImportieren(ergebnis.neue) }
            )
        }
        .sheet(item: $importKDErgebnis) { ergebnis in
            ImportVorschauView(
                titel: "KD-Import: Vorschau",
                ergebnis: ergebnis,
                zeileBeschreibung: { k in
                    var teile = ["\(k.kundennummer) – \(k.name)"]
                    if !k.wohnort.isEmpty { teile.append(k.wohnort) }
                    if !k.mobil.isEmpty { teile.append(k.mobil) }
                    return teile.joined(separator: " · ")
                },
                onImport: { vm.kdImportieren(ergebnis.neue) }
            )
        }
        .alert("Import-Fehler", isPresented: .constant(importFehler != nil), actions: {
            Button("OK") { importFehler = nil }
        }, message: {
            Text(importFehler ?? "")
        })
    }

    // MARK: - Import-Verarbeitung

    private func verarbeitePFAuswahl(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                importPFErgebnis = try StammdatenImporter.ladePF(url: url, bestehende: vm.reinigungskraefte)
            } catch {
                importFehler = error.localizedDescription
            }
        case .failure(let err):
            importFehler = err.localizedDescription
        }
    }

    private func verarbeiteKDAuswahl(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                importKDErgebnis = try StammdatenImporter.ladeKD(url: url, bestehende: vm.kunden)
            } catch {
                importFehler = error.localizedDescription
            }
        case .failure(let err):
            importFehler = err.localizedDescription
        }
    }

    // MARK: - Seitenleiste

    private var seitenleiste: some View {
        List(selection: $bereich) {
            NavigationLink(value: Navigationsbereich.uebersicht) {
                Label("Übersicht", systemImage: "gauge.badge.plus")
            }
            NavigationLink(value: Navigationsbereich.schluesselbewegungen) {
                Label("Schlüsselbewegungen", systemImage: "arrow.left.arrow.right")
            }
            NavigationLink(value: Navigationsbereich.historie) {
                Label("Historie", systemImage: "clock.arrow.circlepath")
            }

            Section {
                NavigationLink(value: Navigationsbereich.kunden) {
                    Label("KD", systemImage: "key.fill")
                }
                NavigationLink(value: Navigationsbereich.reinigungskraefte) {
                    Label("PF", systemImage: "person.2.fill")
                }
            } header: {
                Text("Stammdaten").padding(.leading, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Putzzentrale")
        .safeAreaInset(edge: .bottom) {
            // Warnung in der Seitenleiste wenn Schlüssel überfällig
            let n = vm.ueberfaelligeBewegungen.count
            if n > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(n) überfällig")
                        .font(.caption).foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(.background.opacity(0.95))
            }
        }
    }

    // MARK: - Inhalts-Spalte (Listen)

    @ViewBuilder
    private var inhaltsSpalte: some View {
        switch bereich ?? .uebersicht {
        case .uebersicht:
            // Übersicht ist eine Vollbild-Ansicht — Listenspalte ungenutzt
            Color.clear
        case .schluesselbewegungen:
            SchluesselbewegungenView(auswahl: $ausgewaehlteBewegung)
        case .historie:
            HistorieView(auswahl: $ausgewaehlteBewegung)
        case .kunden:
            KundenView(ausgewaehlterKunde: $ausgewaehlterKunde)
        case .reinigungskraefte:
            ReinigungskraefteView(ausgewaehlt: $ausgewaehlteRK, onZahlenklick: { rk, fokus in
                ausgewaehlteRK = rk
                rkFokus = fokus
            })
        }
    }

    // MARK: - Detail-Spalte

    @ViewBuilder
    private var detailSpalte: some View {
        switch bereich ?? .uebersicht {
        case .uebersicht:
            DashboardView()

        case .schluesselbewegungen:
            if let b = ausgewaehlteBewegung,
               let k = vm.kunde(id: b.kundenId) {
                KundeDetailView(kunde: k, onAktualisiert: { _ in })
                    .id(k.id)
            } else {
                leerZustand(symbol: "arrow.left.arrow.right", text: "Bewegung auswählen")
            }

        case .historie:
            if let b = ausgewaehlteBewegung,
               let k = vm.kunde(id: b.kundenId) {
                KundeDetailView(kunde: k, onAktualisiert: { _ in })
                    .id(k.id)
            } else {
                leerZustand(symbol: "clock.arrow.circlepath", text: "Bewegung auswählen")
            }

        case .kunden:
            if let k = ausgewaehlterKunde {
                KundeDetailView(kunde: k, onAktualisiert: { ausgewaehlterKunde = $0 })
                    .id(k.id)
            } else {
                leerZustand(symbol: "key.fill", text: "KD auswählen")
            }

        case .reinigungskraefte:
            if let r = ausgewaehlteRK {
                ReinigungskraftDetail(
                    rk: r,
                    initialFokus: rkFokus,
                    onAktualisiert: { ausgewaehlteRK = $0 }
                )
                .id(r.id)
            } else {
                leerZustand(symbol: "person.2.fill", text: "PF auswählen")
            }
        }
    }

    // MARK: - Platzhalter (werden in Folge-Iterationen ausgebaut)

    // MARK: - Leerzustand

    private func leerZustand(symbol: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4))
            Text(text).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
