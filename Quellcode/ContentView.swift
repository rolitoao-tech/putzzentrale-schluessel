import SwiftUI

// Navigationsbereiche der Seitenleiste
enum Navigationsbereich: String, Hashable, CaseIterable {
    case dashboard          = "Dashboard"
    case schluessel         = "Schlüssel"
    case kunden             = "Kunden"
    case putzfrauen         = "Putzfrauen"
    case schluesselStamm    = "Schlüssel-Stamm"

    var symbol: String {
        switch self {
        case .dashboard:        return "gauge.badge.plus"
        case .schluessel:       return "key.fill"
        case .kunden:           return "building.2.fill"
        case .putzfrauen:       return "person.2.fill"
        case .schluesselStamm:  return "key.horizontal.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var bereich: Navigationsbereich? = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            seitenleiste
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            NavigationStack {
                detailAnsicht
            }
        }
        .environmentObject(vm)
    }

    // MARK: - Seitenleiste

    private var seitenleiste: some View {
        List(selection: $bereich) {
            NavigationLink(value: Navigationsbereich.dashboard) {
                Label("Dashboard", systemImage: "gauge.badge.plus")
            }
            NavigationLink(value: Navigationsbereich.schluessel) {
                Label("Schlüssel", systemImage: "key.fill")
            }

            Section("Stammdaten") {
                NavigationLink(value: Navigationsbereich.kunden) {
                    Label("Kunden", systemImage: "building.2.fill")
                }
                NavigationLink(value: Navigationsbereich.putzfrauen) {
                    Label("Putzfrauen", systemImage: "person.2.fill")
                }
                NavigationLink(value: Navigationsbereich.schluesselStamm) {
                    Label("Schlüssel-Stamm", systemImage: "key.horizontal.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Putzzentrale")
        // Anzahl offener Pendenzen als Badge
        .safeAreaInset(edge: .bottom) {
            offenePendenzenBadge
        }
    }

    private var offenePendenzenBadge: some View {
        let ueberfaellig = vm.ueberfaelligeBewegungen.count
        return Group {
            if ueberfaellig > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(ueberfaellig) überfällig")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(.background.opacity(0.9))
            }
        }
    }

    // MARK: - Detail-Ansicht

    @ViewBuilder
    private var detailAnsicht: some View {
        switch bereich ?? .dashboard {
        case .dashboard:        DashboardView()
        case .schluessel:       SchluesselListView()
        case .kunden:           KundenView()
        case .putzfrauen:       PutzfrauenView()
        case .schluesselStamm:  SchluesselVerwaltungView()
        }
    }
}
