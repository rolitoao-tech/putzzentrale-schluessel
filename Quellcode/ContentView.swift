import SwiftUI

enum Navigationsbereich: String, Hashable {
    case uebersicht           = "Übersicht"
    case schluesselbewegungen = "Schlüsselbewegungen"
    case historie             = "Historie"
    case kunden               = "Kunden"
    case reinigungskraefte    = "Reinigungskräfte"
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var bereich: Navigationsbereich? = .uebersicht
    @State private var ausgewaehlterKunde: Kunde?
    @State private var ausgewaehlteRK: Reinigungskraft?
    @State private var ausgewaehlteBewegung: Bewegung?
    @State private var spaltenSichtbarkeit: NavigationSplitViewVisibility = .all

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
                    Label("Kunden", systemImage: "key.fill")
                }
                NavigationLink(value: Navigationsbereich.reinigungskraefte) {
                    Label("Reinigungskräfte", systemImage: "person.2.fill")
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
            ReinigungskraefteView(ausgewaehlt: $ausgewaehlteRK)
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
                leerZustand(symbol: "key.fill", text: "Kunde auswählen")
            }

        case .reinigungskraefte:
            if let r = ausgewaehlteRK {
                ReinigungskraftDetail(rk: r, onAktualisiert: { ausgewaehlteRK = $0 })
                    .id(r.id)
            } else {
                leerZustand(symbol: "person.2.fill", text: "Reinigungskraft auswählen")
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
