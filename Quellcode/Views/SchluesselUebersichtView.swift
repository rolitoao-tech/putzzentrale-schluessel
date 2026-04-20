import SwiftUI

// Hauptansicht: alle Kunden mit aktuellem Schlüsselstandort
struct SchluesselUebersichtView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var suchtext = ""
    @State private var nurImUmlauf = false

    private var gefiltert: [Kunde] {
        var liste = vm.kunden
        if nurImUmlauf {
            liste = liste.filter { vm.aktiveBewegung(kundenId: $0.id) != nil }
        }
        if !suchtext.isEmpty {
            liste = liste.filter {
                $0.name.localizedCaseInsensitiveContains(suchtext) ||
                $0.kundennummer.localizedCaseInsensitiveContains(suchtext) ||
                $0.wohnort.localizedCaseInsensitiveContains(suchtext)
            }
        }
        return liste
    }

    var body: some View {
        HSplitView {
            linkeSeite
                .frame(minWidth: 380, idealWidth: 420)
            rechteSeite
        }
        .navigationTitle("Schlüssel-Übersicht")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $nurImUmlauf) {
                    Label("Im Umlauf", systemImage: "arrow.left.arrow.right")
                }
                .toggleStyle(.button)
                .help("Nur Schlüssel anzeigen, die gerade ausgegeben sind")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeNeuenKunden = true } label: {
                    Label("Neuer Kunde", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeuenKunden) {
            KundeFormular(vorlage: nil) { k in
                vm.kundeHinzufuegen(k)
                zeigeNeuenKunden = false
            }
        }
    }

    @State private var ausgewaehlterKunde: Kunde?
    @State private var zeigeNeuenKunden = false

    // MARK: - Linke Seite: Kundenliste

    private var linkeSeite: some View {
        VStack(spacing: 0) {
            // Suchfeld
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Name, Kundennr., Wohnort", text: $suchtext)
                    .textFieldStyle(.plain)
                if !suchtext.isEmpty {
                    Button { suchtext = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Kopfzeile
            HStack {
                Text("Nr.").frame(width: 50, alignment: .leading)
                Text("Name").frame(minWidth: 120, alignment: .leading)
                Text("Wohnort").frame(minWidth: 80, alignment: .leading)
                Spacer()
                Text("Standort").frame(minWidth: 100, alignment: .trailing)
            }
            .font(.caption).foregroundColor(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))

            // Liste
            List(gefiltert, selection: $ausgewaehlterKunde) { k in
                KundenZeile(kunde: k).tag(k)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Rechte Seite: Detail oder Leerstand

    @ViewBuilder
    private var rechteSeite: some View {
        if let k = ausgewaehlterKunde {
            KundeDetailView(
                kunde: k,
                onAktualisiert: { ausgewaehlterKunde = $0 }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4))
                Text("Kunde auswählen").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Zeile in der Kundenliste

struct KundenZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let kunde: Kunde

    var body: some View {
        HStack(spacing: 8) {
            // Status-Punkt
            Circle()
                .fill(statusFarbe)
                .frame(width: 8, height: 8)

            Text(kunde.kundennummer)
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(kunde.name).fontWeight(.medium)
                if !kunde.wohnort.isEmpty {
                    Text(kunde.wohnort).font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            Spacer()

            // Standort-Badge
            standortBadge
        }
        .padding(.vertical, 3)
        .opacity(kunde.aktiv ? 1 : 0.5)
    }

    private var statusFarbe: Color {
        guard let b = vm.aktiveBewegung(kundenId: kunde.id) else { return .green }
        return b.status == .ueberfaellig ? .red : .orange
    }

    @ViewBuilder
    private var standortBadge: some View {
        if let rk = vm.aktuelleReinigungskraft(kundenId: kunde.id) {
            Label(rk.name, systemImage: "person.fill")
                .font(.caption2).foregroundColor(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
        } else {
            Label(kunde.standortText, systemImage: kunde.standortTyp.icon)
                .font(.caption2).foregroundColor(.green)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.10))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Kunden-Detailansicht (rechte Seite)

struct KundeDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var kunde: Kunde
    @State private var zeigeBearbeiten = false
    @State private var zeigeAbgang = false
    @State private var zeigeLoeschen = false

    let onAktualisiert: (Kunde) -> Void

    init(kunde: Kunde, onAktualisiert: @escaping (Kunde) -> Void) {
        _kunde = State(initialValue: kunde)
        self.onAktualisiert = onAktualisiert
    }

    private var bewegungen: [Bewegung] { vm.bewegungen(fuerKunde: kunde.id) }
    private var aktiveBewegung: Bewegung? { vm.aktiveBewegung(kundenId: kunde.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kopfbereich
                standortKarte
                historieSektion
            }
            .padding(20)
        }
        .sheet(isPresented: $zeigeBearbeiten) {
            KundeFormular(vorlage: kunde) { k in
                vm.kundeAktualisieren(k)
                kunde = k
                onAktualisiert(k)
                zeigeBearbeiten = false
            }
        }
        .sheet(isPresented: $zeigeAbgang) {
            BewegungErfassenView(modus: .abgang(vorausgewaehlt: kunde))
        }
        .confirmationDialog("Kunde «\(kunde.name)» löschen?", isPresented: $zeigeLoeschen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { vm.kundeLoeschen(id: kunde.id) }
        } message: { Text("Alle Bewegungen dieses Kunden werden ebenfalls gelöscht.") }
        .onReceive(vm.$kunden) { liste in
            if let aktuell = liste.first(where: { $0.id == kunde.id }) { kunde = aktuell }
        }
    }

    // MARK: - Kopf

    private var kopfbereich: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(kunde.name).font(.title2).fontWeight(.bold)
                    if !kunde.aktiv {
                        Text("Inaktiv").font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 12) {
                    Label("Nr. \(kunde.kundennummer)", systemImage: "number")
                    if !kunde.wohnort.isEmpty {
                        Label(kunde.wohnort, systemImage: "mappin.circle")
                    }
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Button("Bearbeiten") { zeigeBearbeiten = true }.buttonStyle(.bordered)
                Menu {
                    Button("Abgang erfassen") { zeigeAbgang = true }
                        .disabled(aktiveBewegung != nil)
                    Divider()
                    Button("Löschen", role: .destructive) { zeigeLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Standort-Karte

    private var standortKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktueller Standort").font(.headline)

            if let b = aktiveBewegung, let rk = vm.reinigungskraft(id: b.reinigungskraftId) {
                // Schlüssel ist ausgegeben
                HStack(spacing: 12) {
                    Image(systemName: "person.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bei \(rk.name)").fontWeight(.medium)
                        Text("Seit \(b.datumAbgang.anzeigeText) · \(b.grund.rawValue)")
                            .font(.caption).foregroundColor(.secondary)
                        if let er = b.erwarteteRueckgabe {
                            Text("Erwartet am \(er.anzeigeText)")
                                .font(.caption)
                                .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                        }
                    }
                    Spacer()
                    Button("Rückgabe erfassen") {
                        vm.rueckgabeEintragen(bewegungId: b.id)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Schlüssel ist im Büro
                StandortImBueroKarte(kunde: $kunde)
            }
        }
    }

    // MARK: - Bewegungshistorie

    private var historieSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bewegungshistorie (\(bewegungen.count))").font(.headline)
            if bewegungen.isEmpty {
                Text("Noch keine Bewegungen.").foregroundColor(.secondary)
            } else {
                VStack(spacing: 1) {
                    // Kopfzeile
                    HStack {
                        Text("Abgang").frame(width: 85, alignment: .leading)
                        Text("Reinigungskraft").frame(minWidth: 130, alignment: .leading)
                        Text("Grund").frame(width: 110, alignment: .leading)
                        Text("Erwartet").frame(width: 85, alignment: .leading)
                        Text("Rückgabe").frame(width: 85, alignment: .leading)
                        Spacer()
                        Text("Pool").frame(width: 36, alignment: .center)
                        Text("Status").frame(width: 85, alignment: .trailing)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(bewegungen) { b in
                        HistorieZeile(bewegung: b)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Standort-Karte (bearbeitbar)

struct StandortImBueroKarte: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var kunde: Kunde
    @State private var bearbeite = false
    @State private var zeigeAbgang = false
    @State private var typ: StandortTyp = .safe
    @State private var detail = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kunde.standortTyp.icon).foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Im Büro").fontWeight(.medium).foregroundColor(.green)
                Text(kunde.standortText).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("Standort ändern") { bearbeite = true }
                .buttonStyle(.bordered).controlSize(.small)
            Button { zeigeAbgang = true } label: {
                Label("Abgang erfassen", systemImage: "arrow.up.forward.circle")
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(12)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $bearbeite) {
            StandortFormular(typ: typ, detail: detail) { neuerTyp, neuesDetail in
                vm.standortAktualisieren(kundenId: kunde.id, typ: neuerTyp, detail: neuesDetail)
                bearbeite = false
            }
        }
        .sheet(isPresented: $zeigeAbgang) {
            BewegungErfassenView(modus: .abgang(vorausgewaehlt: kunde))
        }
        .onAppear { typ = kunde.standortTyp; detail = kunde.standortDetail }
        .onChange(of: kunde) { k in typ = k.standortTyp; detail = k.standortDetail }
    }
}

// Kleines Sheet zum Standort-Ändern
struct StandortFormular: View {
    @Environment(\.dismiss) private var dismiss
    @State private var typ: StandortTyp
    @State private var hakenNr = ""
    @State private var dossierKuerzel = ""
    let onSpeichern: (StandortTyp, String) -> Void

    init(typ: StandortTyp, detail: String, onSpeichern: @escaping (StandortTyp, String) -> Void) {
        _typ = State(initialValue: typ)
        self.onSpeichern = onSpeichern
        if typ == .safe { _hakenNr = State(initialValue: detail) }
        else { _dossierKuerzel = State(initialValue: detail) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Standort im Büro").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            Divider()
            Form {
                Section {
                    Picker("Aufbewahrung", selection: $typ) {
                        ForEach(StandortTyp.allCases, id: \.self) { t in
                            Label(t.bezeichnung, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if typ == .safe {
                    Section("Haken-Nummer (1–48)") {
                        TextField("z.B. 12", text: $hakenNr)
                    }
                } else {
                    Section("Kürzel Mitarbeiterin") {
                        TextField("z.B. SSI oder MAR", text: $dossierKuerzel)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Speichern") {
                    let detail = typ == .safe ? hakenNr : dossierKuerzel
                    onSpeichern(typ, detail)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 360, height: 280)
    }
}

// MARK: - Historiezeile

struct HistorieZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    @State private var zeigeBearbeiten = false

    var body: some View {
        HStack {
            Text(bewegung.datumAbgang.anzeigeText)
                .font(.caption).frame(width: 85, alignment: .leading)
            Text(vm.rkName(id: bewegung.reinigungskraftId))
                .frame(minWidth: 130, alignment: .leading)
            Text(bewegung.grund.rawValue)
                .font(.caption).frame(width: 110, alignment: .leading)
            Text(bewegung.erwarteteRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 85, alignment: .leading)
            Text(bewegung.datumRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 85, alignment: .leading)
            Spacer()
            Image(systemName: bewegung.poolEingetragen ? "checkmark.circle.fill" : "circle")
                .foregroundColor(bewegung.poolEingetragen ? .green : .secondary)
                .font(.caption).frame(width: 36, alignment: .center)
            Label(bewegung.status.bezeichnung, systemImage: bewegung.status.icon)
                .font(.caption).foregroundColor(bewegung.status.farbe)
                .frame(width: 85, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color(.controlBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture { if bewegung.istOffen { zeigeBearbeiten = true } }
        .sheet(isPresented: $zeigeBearbeiten) {
            BewegungErfassenView(modus: .rueckgabe(bewegung))
        }
    }
}

// MARK: - Kunde-Formular (Neu / Bearbeiten)

struct KundeFormular: View {
    @Environment(\.dismiss) private var dismiss

    var vorlage: Kunde?
    let onSpeichern: (Kunde) -> Void

    @State private var kundennummer = ""
    @State private var name = ""
    @State private var wohnort = ""
    @State private var aktiv = true
    @State private var notizen = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neuer Kunde" : "Kunde bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Kundennummer") {
                    TextField("z.B. 1042", text: $kundennummer)
                }
                Section("Name & Wohnort") {
                    TextField("Name", text: $name)
                    TextField("Wohnort (optional)", text: $wohnort)
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
                    var k = vorlage ?? Kunde()
                    k.kundennummer = kundennummer.trimmingCharacters(in: .whitespaces)
                    k.name = name.trimmingCharacters(in: .whitespaces)
                    k.wohnort = wohnort.trimmingCharacters(in: .whitespaces)
                    k.aktiv = aktiv
                    k.notizen = notizen
                    onSpeichern(k)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                          kundennummer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
        .onAppear {
            if let k = vorlage {
                kundennummer = k.kundennummer
                name = k.name
                wohnort = k.wohnort
                aktiv = k.aktiv
                notizen = k.notizen
            }
        }
    }
}
