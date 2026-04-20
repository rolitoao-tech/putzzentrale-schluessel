import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var zeigeNeueBewegung = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kennzahlenLeiste
                if !vm.ueberfaelligeBewegungen.isEmpty {
                    ueberfaelligSektion
                }
                offeneSektion
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
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

    // MARK: - Kennzahlen

    private var kennzahlenLeiste: some View {
        HStack(spacing: 16) {
            KennzahlKarte(
                titel: "Schlüssel gesamt",
                wert: "\(vm.schluessel.count)",
                symbol: "key.fill",
                farbe: .blue
            )
            KennzahlKarte(
                titel: "Im Umlauf",
                wert: "\(vm.schluesselImUmlauf)",
                symbol: "arrow.left.arrow.right",
                farbe: .orange
            )
            KennzahlKarte(
                titel: "Offene Pendenzen",
                wert: "\(vm.offeneBewegungen.count)",
                symbol: "clock",
                farbe: .purple
            )
            KennzahlKarte(
                titel: "Überfällig",
                wert: "\(vm.ueberfaelligeBewegungen.count)",
                symbol: "exclamationmark.triangle.fill",
                farbe: vm.ueberfaelligeBewegungen.isEmpty ? .secondary : .red
            )
        }
    }

    // MARK: - Überfällige Bewegungen

    private var ueberfaelligSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Überfällig")
                .font(.headline)
                .foregroundColor(.red)

            VStack(spacing: 1) {
                ForEach(vm.ueberfaelligeBewegungen) { b in
                    BewegungsZeile(bewegung: b, hervorheben: true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Alle offenen Bewegungen

    private var offeneSektion: some View {
        let nurOffen = vm.offeneBewegungen.filter { $0.status == .offen }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Offen (\(nurOffen.count))")
                .font(.headline)

            if nurOffen.isEmpty {
                Text("Keine offenen Pendenzen.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 1) {
                    ForEach(nurOffen) { b in
                        BewegungsZeile(bewegung: b, hervorheben: false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Kennzahl-Karte

struct KennzahlKarte: View {
    let titel: String
    let wert: String
    let symbol: String
    let farbe: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .foregroundColor(farbe)
                Spacer()
            }
            Text(wert)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(titel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Bewegungs-Zeile (Dashboard und SchlüsselDetail)

struct BewegungsZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let hervorheben: Bool

    @State private var zeigeRueckgabe = false

    var body: some View {
        HStack(spacing: 12) {
            // Status-Icon
            Image(systemName: bewegung.status.icon)
                .foregroundColor(bewegung.status.farbe)
                .frame(width: 20)

            // Schlüssel + Kunde
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.schluesselName(id: bewegung.schluesselId))
                    .fontWeight(.medium)
                Text(vm.kundeName(id: kundeId))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 160, alignment: .leading)

            // Putzfrau
            Text(vm.putzfrauName(id: bewegung.putzfrauId))
                .frame(minWidth: 120, alignment: .leading)

            // Grund
            Text(bewegung.grund.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            // Abgang
            Text(bewegung.datumAbgang.anzeigeText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Erwartete Rückgabe
            if let er = bewegung.erwarteteRueckgabe {
                Text("bis \(er.anzeigeText)")
                    .font(.caption)
                    .foregroundColor(hervorheben ? .red : .secondary)
            }

            // Schnell-Rückgabe-Button
            Button("Zurück") {
                zeigeRueckgabe = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hervorheben ? Color.red.opacity(0.07) : Color(.controlBackgroundColor))
        .sheet(isPresented: $zeigeRueckgabe) {
            BewegungErfassenView(modus: .rueckgabe(bewegung))
        }
    }

    // Schlüssel-ID → Kunden-ID auflösen
    private var kundeId: Int64 {
        vm.schluessel(id: bewegung.schluesselId)?.kundeId ?? 0
    }
}
