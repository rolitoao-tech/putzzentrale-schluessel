import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var zeigeNeueBewegung = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kennzahlenLeiste
                if !vm.ueberfaelligeBewegungen.isEmpty {
                    pendenzSektion(
                        titel: "Überfällig",
                        titelFarbe: .red,
                        bewegungen: vm.ueberfaelligeBewegungen,
                        hervorheben: true
                    )
                }
                pendenzSektion(
                    titel: "Offen (\(vm.offeneBewegungen.filter { $0.status == .offen }.count))",
                    titelFarbe: .primary,
                    bewegungen: vm.offeneBewegungen.filter { $0.status == .offen },
                    hervorheben: false
                )
            }
            .padding(24)
        }
        .navigationTitle("Übersicht")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeNeueBewegung = true } label: {
                    Label("Schlüssel einfordern", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeueBewegung) {
            BewegungErfassenView(modus: .einfordern())
        }
    }

    // MARK: - Kennzahlen

    private var kennzahlenLeiste: some View {
        HStack(spacing: 16) {
            KennzahlKarte(titel: "Kunden gesamt",    wert: "\(vm.kunden.filter(\.aktiv).count)", symbol: "person.fill",                 farbe: .blue)
            KennzahlKarte(titel: "Im Umlauf",        wert: "\(vm.schluesselImUmlauf)",            symbol: "arrow.left.arrow.right",       farbe: .orange)
            KennzahlKarte(titel: "Offene Pendenzen", wert: "\(vm.offeneBewegungen.count)",         symbol: "clock",                        farbe: .purple)
            KennzahlKarte(titel: "Überfällig",       wert: "\(vm.ueberfaelligeBewegungen.count)",  symbol: "exclamationmark.triangle.fill", farbe: vm.ueberfaelligeBewegungen.isEmpty ? .secondary : .red)
        }
    }

    // MARK: - Pendenz-Sektion

    @ViewBuilder
    private func pendenzSektion(titel: String, titelFarbe: Color, bewegungen: [Bewegung], hervorheben: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline).foregroundColor(titelFarbe)
            if bewegungen.isEmpty {
                Text("Keine offenen Pendenzen.")
                    .foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 1) {
                    // Kopfzeile
                    HStack {
                        Text("Kunde / Zuget. RK").frame(minWidth: 160, alignment: .leading)
                        Text("Aktuell bei").frame(minWidth: 140, alignment: .leading)
                        Text("Grund").frame(minWidth: 100, alignment: .leading)
                        Text("Eingefordert").frame(width: 90, alignment: .leading)
                        Spacer()
                        Text("Erwartet zurück").frame(width: 110, alignment: .trailing)
                        Spacer().frame(width: 90)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(bewegungen) { b in
                        DashboardZeile(bewegung: b, hervorheben: hervorheben)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Kennzahl-Karte

struct KennzahlKarte: View {
    let titel: String; let wert: String; let symbol: String; let farbe: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundColor(farbe)
            Text(wert).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(titel).font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Dashboard-Zeile

struct DashboardZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let hervorheben: Bool

    @State private var zeigeRueckgabe = false

    private var aktuellerAufenthaltsort: String {
        if let rkId = bewegung.stellvertretungRKId { return vm.rkName(id: rkId) }
        return bewegung.aufenthaltsText
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bewegung.status.icon)
                .foregroundColor(bewegung.status.farbe).frame(width: 18)

            // Kunde: Name + Nr. + zugeteilte RK
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.kundeName(id: bewegung.kundenId)).fontWeight(.medium)
                if let k = vm.kunde(id: bewegung.kundenId) {
                    Text("Nr. \(k.kundennummer)").font(.caption2).foregroundColor(.secondary)
                }
                if let rk = vm.zugeteilteReinigungskraft(kundenId: bewegung.kundenId) {
                    Text("RK: \(rk.name)").font(.caption2).foregroundColor(.green.opacity(0.8))
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            // Aktueller Aufenthaltsort
            Text(aktuellerAufenthaltsort)
                .font(.caption)
                .foregroundColor(bewegung.stellvertretungRKId != nil ? .orange : .secondary)
                .frame(minWidth: 140, alignment: .leading)

            Text(bewegung.grund.rawValue)
                .font(.caption).foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            Text(bewegung.datumAbgang.anzeigeText)
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Spacer()

            // Erwartete Rückgabe
            if let er = bewegung.erwarteteRueckgabe {
                Text(er.anzeigeText)
                    .font(.caption)
                    .foregroundColor(hervorheben ? .red : .secondary)
                    .frame(width: 110, alignment: .trailing)
            } else {
                Text("–").font(.caption).foregroundColor(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }

            // Schnell-Rückgabe
            Button("Zurück") { zeigeRueckgabe = true }
                .buttonStyle(.bordered).controlSize(.small)
                .frame(width: 90)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(hervorheben ? Color.red.opacity(0.07) : Color(.controlBackgroundColor))
        .sheet(isPresented: $zeigeRueckgabe) {
            BewegungErfassenView(modus: .rueckgabe(bewegung))
        }
    }
}
