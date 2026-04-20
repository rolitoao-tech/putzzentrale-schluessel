import SwiftUI

struct SchluesselDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    // Lokale Kopie, damit Änderungen (z.B. "verloren") sofort sichtbar sind
    @State private var schluessel: Schluessel
    @State private var zeigeAbgang = false
    @State private var zeigeVorlorenBestaetigung = false

    init(schluessel: Schluessel) {
        _schluessel = State(initialValue: schluessel)
    }

    private var bewegungen: [Bewegung] {
        vm.bewegungen(fuerSchluessel: schluessel.id)
    }

    private var aktiveBewegung: Bewegung? {
        bewegungen.first { $0.istOffen }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopfbereich
                standortKarte
                historieSektion
            }
            .padding(24)
        }
        .navigationTitle(schluessel.bezeichnung)
        .toolbar { aktionenToolbar }
        .sheet(isPresented: $zeigeAbgang) {
            BewegungErfassenView(
                modus: .abgang,
                vorausgewaehlterSchluessel: schluessel
            )
        }
        .confirmationDialog(
            "Schlüssel als verloren markieren?",
            isPresented: $zeigeVorlorenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Als verloren markieren", role: .destructive) {
                vm.schluesselAlsVerloren(schluessel)
                // Lokale Kopie aktualisieren
                schluessel.verloren = true
            }
        } message: {
            Text("Dieser Schritt kann nicht automatisch rückgängig gemacht werden.")
        }
        // Schlüssel-Daten aktualisieren wenn ViewModel neu lädt
        .onReceive(vm.$schluessel) { liste in
            if let aktuell = liste.first(where: { $0.id == schluessel.id }) {
                schluessel = aktuell
            }
        }
    }

    // MARK: - Kopfbereich

    private var kopfbereich: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: schluessel.verloren ? "key.slash.fill" : "key.fill")
                .font(.system(size: 40))
                .foregroundColor(schluessel.verloren ? .red : .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(schluessel.bezeichnung)
                    .font(.title2).fontWeight(.bold)
                Text("Kunde: \(vm.kundeName(id: schluessel.kundeId))")
                    .foregroundColor(.secondary)
                if schluessel.anzahlKopien > 1 {
                    Text("\(schluessel.anzahlKopien) Kopien")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if schluessel.verloren {
                    Label("VERLOREN", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                }
                if !schluessel.notizen.isEmpty {
                    Text(schluessel.notizen)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Aktueller Standort

    private var standortKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktueller Standort")
                .font(.headline)

            if let b = aktiveBewegung,
               let pf = vm.putzfrau(id: b.putzfrauId) {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pf.name).fontWeight(.medium)
                        Text("Seit \(b.datumAbgang.anzeigeText) · \(b.grund.rawValue)")
                            .font(.caption).foregroundColor(.secondary)
                        if let er = b.erwarteteRueckgabe {
                            Text("Erwartet am \(er.anzeigeText)")
                                .font(.caption)
                                .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                        }
                    }
                    Spacer()
                    // Rückgabe direkt hier erfassen
                    Button("Rückgabe erfassen") {
                        vm.rueckgabeEintragen(bewegungId: b.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack {
                    Image(systemName: "building.fill")
                        .foregroundColor(.green)
                    Text("Im Büro")
                        .foregroundColor(.green)
                    Spacer()
                    Button("Abgang erfassen") {
                        zeigeAbgang = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(schluessel.verloren)
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Bewegungs-Historie

    private var historieSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bewegungshistorie (\(bewegungen.count))")
                .font(.headline)

            if bewegungen.isEmpty {
                Text("Noch keine Bewegungen erfasst.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 1) {
                    // Kopfzeile
                    HStack {
                        Text("Datum Abgang").frame(width: 110, alignment: .leading)
                        Text("Putzfrau").frame(width: 140, alignment: .leading)
                        Text("Grund").frame(width: 110, alignment: .leading)
                        Text("Erwartet").frame(width: 90, alignment: .leading)
                        Text("Rückgabe").frame(width: 90, alignment: .leading)
                        Spacer()
                        Text("Status").frame(width: 90, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(bewegungen) { b in
                        HistorieZeile(bewegung: b)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var aktionenToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                zeigeAbgang = true
            } label: {
                Label("Abgang erfassen", systemImage: "arrow.up.forward.circle")
            }
            .disabled(aktiveBewegung != nil || schluessel.verloren)
            .help("Schlüssel an Putzfrau ausgeben")
        }
        ToolbarItem {
            Button {
                zeigeVorlorenBestaetigung = true
            } label: {
                Label("Verloren melden", systemImage: "key.slash")
            }
            .disabled(schluessel.verloren)
            .help("Schlüssel als verloren markieren")
        }
    }
}

// MARK: - Einzelne Zeile in der Historie

struct HistorieZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung

    var body: some View {
        HStack {
            Text(bewegung.datumAbgang.anzeigeText)
                .frame(width: 110, alignment: .leading)
            Text(vm.putzfrauName(id: bewegung.putzfrauId))
                .frame(width: 140, alignment: .leading)
            Text(bewegung.grund.rawValue)
                .font(.caption)
                .frame(width: 110, alignment: .leading)
            Text(bewegung.erwarteteRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(bewegung.datumRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            // Status-Badge
            Label(bewegung.status.bezeichnung, systemImage: bewegung.status.icon)
                .font(.caption)
                .foregroundColor(bewegung.status.farbe)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(.controlBackgroundColor))
    }
}
