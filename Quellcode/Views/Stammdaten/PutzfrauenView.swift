import SwiftUI

struct PutzfrauenView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var suchtext = ""
    @State private var ausgewaehlte: Putzfrau?
    @State private var zeigeFormular = false
    @State private var bearbeitete: Putzfrau?

    private var gefiltert: [Putzfrau] {
        if suchtext.isEmpty { return vm.putzfrauen }
        return vm.putzfrauen.filter {
            $0.name.localizedCaseInsensitiveContains(suchtext)
        }
    }

    var body: some View {
        HSplitView {
            liste
                .frame(minWidth: 240, idealWidth: 280)

            if let p = ausgewaehlte {
                PutzfrauDetailPanel(
                    putzfrau: p,
                    onBearbeiten: { bearbeitete = p; zeigeFormular = true },
                    onAlleZurueck: {
                        vm.alleSchluesselRueck(vonPutzfrauId: p.id)
                    },
                    onLoeschen: {
                        vm.putzfrauLöschen(id: p.id)
                        ausgewaehlte = nil
                    }
                )
            } else {
                Text("Putzfrau auswählen")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Putzfrauen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bearbeitete = nil
                    zeigeFormular = true
                } label: {
                    Label("Neue Putzfrau", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeFormular) {
            PutzfrauFormular(
                vorlage: bearbeitete,
                onSpeichern: { p in
                    if p.id == 0 {
                        vm.putzfrauHinzufuegen(p)
                    } else {
                        vm.putzfrauAktualisieren(p)
                        ausgewaehlte = p
                    }
                    zeigeFormular = false
                }
            )
        }
    }

    private var liste: some View {
        List(gefiltert, selection: $ausgewaehlte) { p in
            PutzfrauZeile(putzfrau: p)
                .tag(p)
        }
        .searchable(text: $suchtext, prompt: "Name suchen")
    }
}

// MARK: - Zeile

struct PutzfrauZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let putzfrau: Putzfrau

    var body: some View {
        HStack {
            Image(systemName: putzfrau.status.icon)
                .foregroundColor(putzfrau.status.farbe)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(putzfrau.name).fontWeight(.medium)
                if !putzfrau.telefon.isEmpty {
                    Text(putzfrau.telefon).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            // Anzahl aktuell ausgeliehener Schlüssel
            let offen = vm.bewegungen(fuerPutzfrau: putzfrau.id, nurOffen: true).count
            if offen > 0 {
                Label("\(offen)", systemImage: "key.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail-Panel

struct PutzfrauDetailPanel: View {
    @EnvironmentObject var vm: AppViewModel
    let putzfrau: Putzfrau
    let onBearbeiten: () -> Void
    let onAlleZurueck: () -> Void
    let onLoeschen: () -> Void

    @State private var zeigeAlleZurueckBestaetigung = false
    @State private var zeigeLoeschenBestaetigung = false

    private var offeneBewegungen: [Bewegung] {
        vm.bewegungen(fuerPutzfrau: putzfrau.id, nurOffen: true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kopf
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(putzfrau.name).font(.title2).fontWeight(.bold)
                        Label(putzfrau.status.bezeichnung, systemImage: putzfrau.status.icon)
                            .foregroundColor(putzfrau.status.farbe)
                            .font(.caption)
                    }
                    Spacer()
                    Button("Bearbeiten") { onBearbeiten() }
                        .buttonStyle(.bordered)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    if !putzfrau.telefon.isEmpty {
                        GridRow {
                            Text("Telefon").foregroundColor(.secondary)
                            Text(putzfrau.telefon)
                        }
                    }
                    if !putzfrau.email.isEmpty {
                        GridRow {
                            Text("E-Mail").foregroundColor(.secondary)
                            Text(putzfrau.email)
                        }
                    }
                }

                if !putzfrau.notizen.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen").foregroundColor(.secondary).font(.caption)
                        Text(putzfrau.notizen)
                    }
                }

                // Aktuell ausgeliehene Schlüssel
                if !offeneBewegungen.isEmpty {
                    Divider()
                    HStack {
                        Text("Aktuell \(offeneBewegungen.count) Schlüssel ausgeliehen")
                            .font(.headline)
                        Spacer()
                        Button("Alle zurück ins Büro") {
                            zeigeAlleZurueckBestaetigung = true
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(offeneBewegungen) { b in
                        HStack {
                            Image(systemName: b.status.icon)
                                .foregroundColor(b.status.farbe)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.schluesselName(id: b.schluesselId))
                                    .fontWeight(.medium)
                                Text("Seit \(b.datumAbgang.anzeigeText) · \(b.grund.rawValue)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let er = b.erwarteteRueckgabe {
                                Text("bis \(er.anzeigeText)")
                                    .font(.caption)
                                    .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                            }
                        }
                        .padding(8)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Divider()
                Button("Putzfrau löschen", role: .destructive) {
                    zeigeLoeschenBestaetigung = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding(20)
        }
        .confirmationDialog(
            "Alle Schlüssel von «\(putzfrau.name)» als zurückgegeben markieren?",
            isPresented: $zeigeAlleZurueckBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Alle als zurück markieren") { onAlleZurueck() }
        }
        .confirmationDialog(
            "Putzfrau «\(putzfrau.name)» löschen?",
            isPresented: $zeigeLoeschenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { onLoeschen() }
        } message: {
            Text("Offene Bewegungen bleiben erhalten.")
        }
    }
}

// MARK: - Formular (Neu / Bearbeiten)

struct PutzfrauFormular: View {
    @Environment(\.dismiss) private var dismiss

    var vorlage: Putzfrau?
    let onSpeichern: (Putzfrau) -> Void

    @State private var name = ""
    @State private var telefon = ""
    @State private var email = ""
    @State private var status = PutzfrauStatus.aktiv
    @State private var notizen = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neue Putzfrau" : "Putzfrau bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Name") {
                    TextField("Vor- und Nachname", text: $name)
                }
                Section("Kontakt") {
                    TextField("Telefonnummer", text: $telefon)
                    TextField("E-Mail-Adresse", text: $email)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(PutzfrauStatus.allCases, id: \.self) { s in
                            Label(s.bezeichnung, systemImage: s.icon).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notizen") {
                    TextEditor(text: $notizen).frame(height: 60)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Speichern") {
                    var p = vorlage ?? Putzfrau()
                    p.name = name; p.telefon = telefon
                    p.email = email; p.status = status; p.notizen = notizen
                    onSpeichern(p)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 460)
        .onAppear {
            if let p = vorlage {
                name = p.name; telefon = p.telefon
                email = p.email; status = p.status; notizen = p.notizen
            }
        }
    }
}
