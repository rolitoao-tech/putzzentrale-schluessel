import SwiftUI

struct ReinigungskraefteView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var ausgewaehlt: Reinigungskraft?
    @State private var zeigeFormular = false
    @State private var bearbeitete: Reinigungskraft?

    var body: some View {
        HSplitView {
            linkeSeite.frame(minWidth: 240, idealWidth: 260)
            rechteSeite
        }
        .navigationTitle("Reinigungskräfte")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bearbeitete = nil
                    zeigeFormular = true
                } label: {
                    Label("Neue Reinigungskraft", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeFormular) {
            ReinigungskraftFormular(vorlage: bearbeitete) { r in
                if r.id == 0 {
                    vm.rkHinzufuegen(r)
                } else {
                    vm.rkAktualisieren(r)
                    ausgewaehlt = r
                }
                zeigeFormular = false
            }
        }
    }

    private var linkeSeite: some View {
        List(vm.reinigungskraefte, selection: $ausgewaehlt) { r in
            ReinigungskraftZeile(rk: r).tag(r)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var rechteSeite: some View {
        if let r = ausgewaehlt {
            ReinigungskraftDetail(
                rk: r,
                onBearbeiten: { bearbeitete = r; zeigeFormular = true }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4))
                Text("Reinigungskraft auswählen").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Listenzeile

struct ReinigungskraftZeile: View {
    let rk: Reinigungskraft

    var body: some View {
        HStack {
            Circle()
                .fill(rk.aktiv ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(rk.name).fontWeight(.medium)
            Spacer()
            if !rk.aktiv {
                Text("Inaktiv").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(rk.aktiv ? 1 : 0.6)
    }
}

// MARK: - Detailansicht

struct ReinigungskraftDetail: View {
    @EnvironmentObject var vm: AppViewModel
    let rk: Reinigungskraft
    let onBearbeiten: () -> Void

    @State private var zeigeAlleZurueck = false
    @State private var zeigeLoeschen = false

    private var offeneBewegungen: [Bewegung] {
        vm.bewegungen(fuerRK: rk.id, nurOffen: true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kopfbereich
                if !offeneBewegungen.isEmpty {
                    offeneSektion
                }
                historieSektion
            }
            .padding(20)
        }
        .confirmationDialog(
            "Alle Schlüssel von \(rk.name) zurück?",
            isPresented: $zeigeAlleZurueck,
            titleVisibility: .visible
        ) {
            Button("Alle zurück") { vm.alleSchluesselZurueck(vonRKId: rk.id) }
        } message: {
            Text("\(offeneBewegungen.count) offene Bewegung(en) werden als zurückgegeben markiert.")
        }
        .confirmationDialog(
            "Reinigungskraft «\(rk.name)» löschen?",
            isPresented: $zeigeLoeschen,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { vm.rkLoeschen(id: rk.id) }
        } message: {
            Text("Alle Bewegungen dieser Reinigungskraft bleiben erhalten.")
        }
    }

    private var kopfbereich: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rk.name).font(.title2).fontWeight(.bold)
                    if !rk.aktiv {
                        Text("Inaktiv").font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                if !offeneBewegungen.isEmpty {
                    Label("\(offeneBewegungen.count) Schlüssel im Umlauf", systemImage: "key.fill")
                        .font(.caption).foregroundColor(.orange)
                }
            }
            Spacer()
            HStack {
                Button("Bearbeiten") { onBearbeiten() }.buttonStyle(.bordered)
                if !offeneBewegungen.isEmpty {
                    Button("Alle zurück") { zeigeAlleZurueck = true }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                }
                Menu {
                    Button("Löschen", role: .destructive) { zeigeLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var offeneSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktuell im Umlauf (\(offeneBewegungen.count))").font(.headline).foregroundColor(.orange)
            VStack(spacing: 1) {
                ForEach(offeneBewegungen) { b in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.kundeName(id: b.kundenId)).fontWeight(.medium)
                            if let k = vm.kunde(id: b.kundenId) {
                                Text("Nr. \(k.kundennummer)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .frame(minWidth: 150, alignment: .leading)
                        Text(b.datumAbgang.anzeigeText).font(.caption).foregroundColor(.secondary)
                            .frame(width: 85, alignment: .leading)
                        Spacer()
                        if let er = b.erwarteteRueckgabe {
                            Text(er.anzeigeText)
                                .font(.caption)
                                .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                        }
                        Image(systemName: b.status.icon)
                            .foregroundColor(b.status.farbe)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var historieSektion: some View {
        let alle = vm.bewegungen(fuerRK: rk.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Bewegungshistorie (\(alle.count))").font(.headline)
            if alle.isEmpty {
                Text("Noch keine Bewegungen.").foregroundColor(.secondary)
            } else {
                VStack(spacing: 1) {
                    HStack {
                        Text("Kunde").frame(minWidth: 150, alignment: .leading)
                        Text("Abgang").frame(width: 85, alignment: .leading)
                        Text("Grund").frame(width: 110, alignment: .leading)
                        Spacer()
                        Text("Rückgabe").frame(width: 85, alignment: .trailing)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(alle) { b in
                        HStack {
                            Text(vm.kundeName(id: b.kundenId))
                                .frame(minWidth: 150, alignment: .leading)
                            Text(b.datumAbgang.anzeigeText)
                                .font(.caption).foregroundColor(.secondary)
                                .frame(width: 85, alignment: .leading)
                            Text(b.grund.rawValue)
                                .font(.caption).foregroundColor(.secondary)
                                .frame(width: 110, alignment: .leading)
                            Spacer()
                            Text(b.datumRueckgabe.map { $0.anzeigeText } ?? "–")
                                .font(.caption).foregroundColor(.secondary)
                                .frame(width: 85, alignment: .trailing)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(.controlBackgroundColor))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Formular

struct ReinigungskraftFormular: View {
    @Environment(\.dismiss) private var dismiss

    var vorlage: Reinigungskraft?
    let onSpeichern: (Reinigungskraft) -> Void

    @State private var name = ""
    @State private var aktiv = true
    @State private var notizen = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neue Reinigungskraft" : "Reinigungskraft bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section {
                    Toggle("Aktiv", isOn: $aktiv)
                }
                Section("Notizen (optional)") {
                    TextEditor(text: $notizen).frame(height: 60)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Speichern") {
                    var r = vorlage ?? Reinigungskraft()
                    r.name = name.trimmingCharacters(in: .whitespaces)
                    r.aktiv = aktiv
                    r.notizen = notizen
                    onSpeichern(r)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 360, height: 320)
        .onAppear {
            if let r = vorlage {
                name = r.name; aktiv = r.aktiv; notizen = r.notizen
            }
        }
    }
}
