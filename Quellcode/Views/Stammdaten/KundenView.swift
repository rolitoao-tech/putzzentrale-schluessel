import SwiftUI

struct KundenView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var suchtext = ""
    @State private var ausgewaehlterKunde: Kunde?
    @State private var zeigeFormular = false
    @State private var bearbeiteterKunde: Kunde?

    private var gefiltert: [Kunde] {
        if suchtext.isEmpty { return vm.kunden }
        return vm.kunden.filter {
            $0.name.localizedCaseInsensitiveContains(suchtext) ||
            $0.objekt.localizedCaseInsensitiveContains(suchtext)
        }
    }

    var body: some View {
        HSplitView {
            // Linke Spalte: Liste
            kundeListe
                .frame(minWidth: 260, idealWidth: 300)

            // Rechte Spalte: Detail / Leerstand
            if let k = ausgewaehlterKunde {
                KundeDetailPanel(
                    kunde: k,
                    onBearbeiten: { bearbeiteterKunde = k; zeigeFormular = true },
                    onLoeschen: {
                        vm.kundeLöschen(id: k.id)
                        ausgewaehlterKunde = nil
                    }
                )
            } else {
                leereAnsicht
            }
        }
        .navigationTitle("Kunden")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bearbeiteterKunde = nil
                    zeigeFormular = true
                } label: {
                    Label("Neuer Kunde", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeFormular) {
            KundeFormular(
                vorlage: bearbeiteterKunde,
                onSpeichern: { k in
                    if k.id == 0 {
                        vm.kundeHinzufuegen(k)
                    } else {
                        vm.kundeAktualisieren(k)
                        ausgewaehlterKunde = k
                    }
                    zeigeFormular = false
                }
            )
        }
    }

    private var kundeListe: some View {
        List(gefiltert, selection: $ausgewaehlterKunde) { k in
            KundeZeile(kunde: k)
                .tag(k)
        }
        .searchable(text: $suchtext, prompt: "Name oder Objekt")
    }

    private var leereAnsicht: some View {
        Text("Kunde auswählen")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Zeile

struct KundeZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let kunde: Kunde

    var body: some View {
        HStack {
            Circle()
                .fill(kunde.status.farbe)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(kunde.name).fontWeight(.medium)
                if !kunde.objekt.isEmpty {
                    Text(kunde.objekt).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            // Anzahl Schlüssel dieses Kunden
            let anzahl = vm.schluessel.filter { $0.kundeId == kunde.id }.count
            if anzahl > 0 {
                Label("\(anzahl)", systemImage: "key.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail-Panel

struct KundeDetailPanel: View {
    @EnvironmentObject var vm: AppViewModel
    let kunde: Kunde
    let onBearbeiten: () -> Void
    let onLoeschen: () -> Void

    @State private var zeigeLoeschenBestaetigung = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kopf
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kunde.name).font(.title2).fontWeight(.bold)
                        Label(kunde.status.bezeichnung, systemImage: "circle.fill")
                            .foregroundColor(kunde.status.farbe)
                            .font(.caption)
                    }
                    Spacer()
                    Button("Bearbeiten") { onBearbeiten() }
                        .buttonStyle(.bordered)
                }

                Divider()

                // Stammdaten
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    if !kunde.adresse.isEmpty {
                        GridRow {
                            Text("Adresse").foregroundColor(.secondary)
                            Text(kunde.adresse)
                        }
                    }
                    if !kunde.objekt.isEmpty {
                        GridRow {
                            Text("Objekt").foregroundColor(.secondary)
                            Text(kunde.objekt)
                        }
                    }
                }

                if !kunde.notizen.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen").foregroundColor(.secondary).font(.caption)
                        Text(kunde.notizen)
                    }
                }

                // Schlüssel dieses Kunden
                let schluessel = vm.schluessel.filter { $0.kundeId == kunde.id }
                if !schluessel.isEmpty {
                    Divider()
                    Text("Schlüssel (\(schluessel.count))").font(.headline)
                    ForEach(schluessel) { s in
                        SchluesselZeile(schluessel: s)
                    }
                }

                // Löschen
                Divider()
                Button("Kunde löschen", role: .destructive) {
                    zeigeLoeschenBestaetigung = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding(20)
        }
        .confirmationDialog(
            "Kunde «\(kunde.name)» löschen?",
            isPresented: $zeigeLoeschenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { onLoeschen() }
        } message: {
            Text("Zugehörige Schlüssel und Bewegungen bleiben erhalten.")
        }
    }
}

// MARK: - Formular (Neu / Bearbeiten)

struct KundeFormular: View {
    @Environment(\.dismiss) private var dismiss

    var vorlage: Kunde?
    let onSpeichern: (Kunde) -> Void

    @State private var name = ""
    @State private var adresse = ""
    @State private var objekt = ""
    @State private var status = KundeStatus.aktiv
    @State private var notizen = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neuer Kunde" : "Kunde bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Name") {
                    TextField("Firmen- oder Kundenname", text: $name)
                }
                Section("Adresse & Objekt") {
                    TextField("Adresse", text: $adresse)
                    TextField("Objekt / Liegenschaft", text: $objekt)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(KundeStatus.allCases, id: \.self) { s in
                            Text(s.bezeichnung).tag(s)
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
                    var k = vorlage ?? Kunde()
                    k.name = name
                    k.adresse = adresse
                    k.objekt = objekt
                    k.status = status
                    k.notizen = notizen
                    onSpeichern(k)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 440)
        .onAppear {
            if let k = vorlage {
                name = k.name; adresse = k.adresse
                objekt = k.objekt; status = k.status; notizen = k.notizen
            }
        }
    }
}
