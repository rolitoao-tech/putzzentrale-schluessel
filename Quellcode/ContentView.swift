import SwiftUI

enum Navigationsbereich: String, Hashable {
    case dashboard        = "Dashboard"
    case schluessel       = "Schlüssel-Übersicht"
    case reinigungskraefte = "Reinigungskräfte"
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var bereich: Navigationsbereich? = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            seitenleiste
                .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            NavigationStack {
                detailAnsicht
            }
        }
        .environmentObject(vm)
    }

    private var seitenleiste: some View {
        List(selection: $bereich) {
            NavigationLink(value: Navigationsbereich.dashboard) {
                Label("Dashboard", systemImage: "gauge.badge.plus")
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

    @ViewBuilder
    private var detailAnsicht: some View {
        switch bereich ?? .dashboard {
        case .dashboard:          DashboardView()
        case .schluessel:         SchluesselUebersichtView()
        case .reinigungskraefte:  ReinigungskraefteView()
        }
    }
}
