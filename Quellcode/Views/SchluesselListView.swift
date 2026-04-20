import SwiftUI

struct SchluesselListView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var suchtext = ""
    @State private var zeigeNeueBewegung = false

    private var gefiltert: [Schluessel] {
        if suchtext.isEmpty { return vm.schluessel }
        return vm.schluessel.filter {
            $0.bezeichnung.localizedCaseInsensitiveContains(suchtext) ||
            vm.kundeName(id: $0.kundeId).localizedCaseInsensitiveContains(suchtext)
        }
    }

    var body: some View {
        List(gefiltert) { s in
            NavigationLink(value: s) {
                SchluesselZeile(schluessel: s)
            }
        }
        .navigationTitle("Schlüssel")
        .navigationDestination(for: Schluessel.self) { s in
            SchluesselDetailView(schluessel: s)
        }
        .searchable(text: $suchtext, prompt: "Suche nach Schlüssel oder Kunde")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeueBewegung = true
                } label: {
                    Label("Abgang erfassen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeueBewegung) {
            BewegungErfassenView(modus: .abgang)
        }
    }
}

// MARK: - Zeile in der Schlüsselliste

struct SchluesselZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let schluessel: Schluessel

    var body: some View {
        HStack(spacing: 12) {
            // Status-Indikator
            Circle()
                .fill(statusFarbe)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(schluessel.bezeichnung)
                        .fontWeight(.medium)
                    if schluessel.verloren {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                Text(vm.kundeName(id: schluessel.kundeId))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Aktueller Standort
            if let pf = vm.aktuellerInhaber(schluesselId: schluessel.id) {
                Label(pf.name, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !schluessel.verloren {
                Label("Im Büro", systemImage: "building.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Anzahl Kopien
            if schluessel.anzahlKopien > 1 {
                Text("\(schluessel.anzahlKopien)×")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var statusFarbe: Color {
        if schluessel.verloren { return .red }
        return vm.aktuellerInhaber(schluesselId: schluessel.id) != nil ? .orange : .green
    }
}
