import SwiftUI

enum Navigationsbereich: String, Hashable {
    case dashboard        = "Übersicht"
    case schluessel       = "Schlüssel-Übersicht"
    case reinigungskraefte = "Reinigungskräfte"
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var bereich: Navigationsbereich? = .dashboard
    @State private var ausgewaehlterKunde: Kunde?
    @State private var ausgewaehlteRK: Reinigungskraft?
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
            NavigationLink(value: Navigationsbereich.dashboard) {
                Label("Übersicht", systemImage: "gauge.badge.plus")
            }
            NavigationLink(value: Navigationsbereich.schluessel) {
                Label("Schlüssel-Übersicht", systemImage: "key.fill")
            }

            Section("Stammdaten") {
                NavigationLink(value: Navigationsbereich.reinigungskraefte) {
                    Label("Reinigungskräfte", systemImage: "person.2.fill")
                }
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
        switch bereich ?? .dashboard {
        case .dashboard:
            // Wird per spaltenSichtbarkeit ausgeblendet
            Color.clear
        case .schluessel:
            SchluesselUebersichtView(ausgewaehlterKunde: $ausgewaehlterKunde)
        case .reinigungskraefte:
            ReinigungskraefteView(ausgewaehlt: $ausgewaehlteRK)
        }
    }

    // MARK: - Detail-Spalte

    @ViewBuilder
    private var detailSpalte: some View {
        switch bereich ?? .dashboard {
        case .dashboard:
            DashboardView()

        case .schluessel:
            if let k = ausgewaehlterKunde {
                KundeDetailView(kunde: k, onAktualisiert: { ausgewaehlterKunde = $0 })
                    .id(k.id)  // erzwingt Neuaufbau bei Kundenwechsel
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
