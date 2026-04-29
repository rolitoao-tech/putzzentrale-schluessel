import SwiftUI

// Operative Sicht aller offenen + überfälligen Schlüsselbewegungen.
// Auswahl einer Zeile zeigt rechts die Detail-Ansicht des zugehörigen Kunden.
struct SchluesselbewegungenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var auswahl: Bewegung?
    @State private var nurUeberfaellig = false
    @State private var zeigeNeueBewegung = false

    private var sortierteBewegungen: [Bewegung] {
        var liste = vm.offeneBewegungen
        if nurUeberfaellig {
            liste = liste.filter { $0.status == .ueberfaellig }
        }
        // Überfällige zuerst, dann nach erwarteter Rückgabe aufsteigend
        return liste.sorted { a, b in
            let aUe = a.status == .ueberfaellig
            let bUe = b.status == .ueberfaellig
            if aUe != bUe { return aUe }
            let aDate = a.erwarteteRueckgabe ?? .distantFuture
            let bDate = b.erwarteteRueckgabe ?? .distantFuture
            return aDate < bDate
        }
    }

    var body: some View {
        let anzahlUeberfaellig = vm.ueberfaelligeBewegungen.count
        VStack(spacing: 0) {
            // Filter-Leiste
            HStack {
                Toggle(isOn: $nurUeberfaellig) {
                    Label("Nur überfällig", systemImage: "exclamationmark.triangle.fill")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Liste auf überfällige Bewegungen einschränken")
                Spacer()
                // Status-Anzeige: wieviele sind überfällig
                HStack(spacing: 4) {
                    Image(systemName: anzahlUeberfaellig > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text("\(anzahlUeberfaellig) überfällig")
                }
                .font(.caption)
                .foregroundColor(anzahlUeberfaellig > 0 ? .red : .green)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            Divider()

            if sortierteBewegungen.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32)).foregroundColor(.green.opacity(0.6))
                    Text(nurUeberfaellig ? "Keine überfälligen Bewegungen." : "Keine offenen Bewegungen.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortierteBewegungen) { b in
                            BewegungZeile(bewegung: b, ausgewaehlt: auswahl?.id == b.id)
                                .background(auswahl?.id == b.id
                                    ? Color.accentColor.opacity(0.15)
                                    : Color(.controlBackgroundColor))
                                .contentShape(Rectangle())
                                .onTapGesture { auswahl = b }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.controlBackgroundColor))
            }
        }
        .navigationTitle("Schlüsselbewegungen")
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
}

// MARK: - Listenzeile

private struct BewegungZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let ausgewaehlt: Bool

    @State private var zeigeRueckgabe = false

    private var aktuellerStandort: String {
        if let rkId = bewegung.stellvertretungRKId { return vm.rkName(id: rkId) }
        return bewegung.aufenthaltsText
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: bewegung.status.icon)
                .foregroundColor(bewegung.status.farbe)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                // Zeile 1: Kundenname
                Text(vm.kundeName(id: bewegung.kundenId))
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Zeile 2: Nr. + zugeteilte RK
                HStack(spacing: 6) {
                    if let k = vm.kunde(id: bewegung.kundenId) {
                        Text("Nr. \(k.kundennummer)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    if let rk = vm.zugeteilteReinigungskraft(kundenId: bewegung.kundenId) {
                        Text("·").font(.caption2).foregroundColor(.secondary)
                        Text("RK: \(rk.name)")
                            .font(.caption2).foregroundColor(.green.opacity(0.8))
                    }
                }
                .lineLimit(1)

                // Zeile 3: Aktueller Standort + Datum
                HStack(spacing: 6) {
                    Text(aktuellerStandort)
                        .font(.caption)
                        .foregroundColor(bewegung.stellvertretungRKId != nil ? .orange : .secondary)
                    Text("·").font(.caption2).foregroundColor(.secondary)
                    if let er = bewegung.erwarteteRueckgabe {
                        Text("erw. \(er.anzeigeText)")
                            .font(.caption)
                            .foregroundColor(bewegung.status == .ueberfaellig ? .red : .secondary)
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Schnell-Rückgabe
            Button("Zurück") { zeigeRueckgabe = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .sheet(isPresented: $zeigeRueckgabe) {
            BewegungErfassenView(modus: .rueckgabe(bewegung))
        }
    }
}
