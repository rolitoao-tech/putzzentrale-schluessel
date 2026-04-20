import SwiftUI

struct SchluesselVerwaltungView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var suchtext = ""
    @State private var ausgewaehlter: Schluessel?
    @State private var zeigeFormular = false
    @State private var bearbeiteter: Schluessel?

    private var gefiltert: [Schluessel] {
        if suchtext.isEmpty { return vm.schluessel }
        return vm.schluessel.filter {
            $0.bezeichnung.localizedCaseInsensitiveContains(suchtext) ||
            vm.kundeName(id: $0.kundeId).localizedCaseInsensitiveContains(suchtext)
        }
    }

    var body: some View {
        HSplitView {
            liste
                .frame(minWidth: 260, idealWidth: 300)

            if let s = ausgewaehlter {
                SchluesselStammDetail(
                    schluessel: s,
                    onBearbeiten: { bearbeiteter = s; zeigeFormular = true },
                    onLoeschen: {
                        vm.schluesselLoeschen(id: s.id)
                        ausgewaehlter = nil
                    }
                )
            } else {
                Text("Schlüssel auswählen")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Schlüssel-Stamm")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bearbeiteter = nil
                    zeigeFormular = true
                } label: {
                    Label("Neuer Schlüssel", systemImage: "plus")
                }
                .disabled(vm.kunden.isEmpty)
                .help(vm.kunden.isEmpty ? "Zuerst einen Kunden anlegen" : "Neuen Schlüssel erfassen")
            }
        }
        .sheet(isPresented: $zeigeFormular) {
            SchluesselFormular(
                vorlage: bearbeiteter,
                onSpeichern: { s in
                    if s.id == 0 {
                        vm.schluesselHinzufuegen(s)
                    } else {
                        vm.schluesselAktualisieren(s)
                        ausgewaehlter = s
                    }
                    zeigeFormular = false
                }
            )
        }
    }

    private var liste: some View {
        List(gefiltert, selection: $ausgewaehlter) { s in
            SchluesselStammZeile(schluessel: s)
                .tag(s)
        }
        .searchable(text: $suchtext, prompt: "Bezeichnung oder Kunde")
    }
}

// MARK: - Zeile

struct SchluesselStammZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let schluessel: Schluessel

    var body: some View {
        HStack {
            Image(systemName: schluessel.verloren ? "key.slash.fill" : "key.fill")
                .foregroundColor(schluessel.verloren ? .red : .accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(schluessel.bezeichnung).fontWeight(.medium)
                Text(vm.kundeName(id: schluessel.kundeId))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if schluessel.anzahlKopien > 1 {
                Text("\(schluessel.anzahlKopien)×")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail-Panel

struct SchluesselStammDetail: View {
    @EnvironmentObject var vm: AppViewModel
    let schluessel: Schluessel
    let onBearbeiten: () -> Void
    let onLoeschen: () -> Void

    @State private var zeigeLoeschenBestaetigung = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: schluessel.verloren ? "key.slash.fill" : "key.fill")
                                .foregroundColor(schluessel.verloren ? .red : .accentColor)
                            Text(schluessel.bezeichnung).font(.title2).fontWeight(.bold)
                        }
                        if schluessel.verloren {
                            Label("Verloren", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red).font(.caption)
                        }
                    }
                    Spacer()
                    Button("Bearbeiten") { onBearbeiten() }
                        .buttonStyle(.bordered)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Kunde").foregroundColor(.secondary)
                        Text(vm.kundeName(id: schluessel.kundeId))
                    }
                    GridRow {
                        Text("Anzahl Kopien").foregroundColor(.secondary)
                        Text("\(schluessel.anzahlKopien)")
                    }
                    GridRow {
                        Text("Aktuell bei").foregroundColor(.secondary)
                        if let pf = vm.aktuellerInhaber(schluesselId: schluessel.id) {
                            Label(pf.name, systemImage: "person.fill").foregroundColor(.orange)
                        } else if !schluessel.verloren {
                            Label("Im Büro", systemImage: "building.fill").foregroundColor(.green)
                        } else {
                            Text("–")
                        }
                    }
                }

                if !schluessel.notizen.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen").foregroundColor(.secondary).font(.caption)
                        Text(schluessel.notizen)
                    }
                }

                Divider()
                Button("Schlüssel löschen", role: .destructive) {
                    zeigeLoeschenBestaetigung = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding(20)
        }
        .confirmationDialog(
            "Schlüssel «\(schluessel.bezeichnung)» löschen?",
            isPresented: $zeigeLoeschenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { onLoeschen() }
        } message: {
            Text("Alle zugehörigen Bewegungen werden ebenfalls gelöscht.")
        }
    }
}

// MARK: - Formular (Neu / Bearbeiten)

struct SchluesselFormular: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var vorlage: Schluessel?
    let onSpeichern: (Schluessel) -> Void

    @State private var bezeichnung = ""
    @State private var gewaehlterKunde: Kunde?
    @State private var anzahlKopien = 1
    @State private var notizen = ""
    @State private var verloren = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neuer Schlüssel" : "Schlüssel bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Bezeichnung") {
                    TextField("z.B. Haustür, Tresor, Hinterer Eingang", text: $bezeichnung)
                }
                Section("Zuordnung") {
                    Picker("Kunde", selection: $gewaehlterKunde) {
                        Text("Bitte auswählen").tag(Optional<Kunde>(nil))
                        ForEach(vm.kunden.filter { $0.status == .aktiv }) { k in
                            Text(k.name).tag(Optional(k))
                        }
                    }
                    Stepper("Anzahl Kopien: \(anzahlKopien)", value: $anzahlKopien, in: 1...20)
                }
                if vorlage != nil {
                    Section("Status") {
                        Toggle("Als verloren markiert", isOn: $verloren)
                            .tint(.red)
                    }
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
                    var s = vorlage ?? Schluessel()
                    s.bezeichnung = bezeichnung
                    s.kundeId = gewaehlterKunde?.id ?? 0
                    s.anzahlKopien = anzahlKopien
                    s.notizen = notizen
                    s.verloren = verloren
                    onSpeichern(s)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty || gewaehlterKunde == nil)
            }
            .padding()
        }
        .frame(width: 440, height: 420)
        .onAppear {
            if let s = vorlage {
                bezeichnung = s.bezeichnung
                gewaehlterKunde = vm.kunde(id: s.kundeId)
                anzahlKopien = s.anzahlKopien
                notizen = s.notizen
                verloren = s.verloren
            }
        }
    }
}
