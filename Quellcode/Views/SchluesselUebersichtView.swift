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

    @State private var ausgewaehlterKunde: Kunde?
    @State private var zeigeNeuenKunden = false

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
                .help("Nur Schlüssel anzeigen, die gerade nicht bei der zugeteilten RK sind")
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

    // MARK: - Linke Seite: Kundenliste

    private var linkeSeite: some View {
        VStack(spacing: 0) {
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
        if let b = vm.aktiveBewegung(kundenId: kunde.id) {
            if let rkId = b.stellvertretungRKId {
                // Bei Stellvertretung
                Label(vm.rkName(id: rkId), systemImage: "person.2.fill")
                    .font(.caption2).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                // Im Büro
                Label("Im Büro", systemImage: "building.2.fill")
                    .font(.caption2).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        } else {
            // Normalzustand: bei zugeteilter RK
            if let rk = vm.zugeteilteReinigungskraft(kundenId: kunde.id) {
                Label(rk.name, systemImage: "person.fill")
                    .font(.caption2).foregroundColor(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.10))
                    .clipShape(Capsule())
            } else {
                Label(kunde.standortText, systemImage: kunde.standortTyp.icon)
                    .font(.caption2).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Kunden-Detailansicht (rechte Seite)

struct KundeDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var kunde: Kunde
    @State private var zeigeBearbeiten = false
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
                    if let rk = vm.zugeteilteReinigungskraft(kundenId: kunde.id) {
                        Label(rk.name, systemImage: "person.fill").foregroundColor(.green)
                    }
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Button("Bearbeiten") { zeigeBearbeiten = true }.buttonStyle(.bordered)
                Menu {
                    Button("Löschen", role: .destructive) { zeigeLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Standort-Karte

    @ViewBuilder
    private var standortKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktueller Standort").font(.headline)

            if let b = aktiveBewegung {
                SchluesselUnterwegsKarte(bewegung: b, kunde: kunde)
            } else {
                SchluesselBeiRKKarte(kunde: $kunde)
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
                    HStack {
                        Text("Eingefordert").frame(width: 90, alignment: .leading)
                        Text("Aktuell bei").frame(minWidth: 130, alignment: .leading)
                        Text("Grund").frame(width: 110, alignment: .leading)
                        Text("Erwartet").frame(width: 85, alignment: .leading)
                        Text("Zurück").frame(width: 85, alignment: .leading)
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

// MARK: - Karte: Schlüssel nicht bei zugeteilter RK (Bewegung offen)

struct SchluesselUnterwegsKarte: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let kunde: Kunde
    @State private var zeigeStellvertretung = false
    @State private var zeigeRueckgabe = false

    private var aufenthaltsort: String {
        if let rkId = bewegung.stellvertretungRKId {
            return "Bei \(vm.rkName(id: rkId)) (Stellvertretung)"
        }
        return "Im Büro"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: bewegung.stellvertretungRKId != nil ? "person.2.fill" : "building.2.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(aufenthaltsort).fontWeight(.medium).foregroundColor(.orange)
                    Text("Eingefordert am \(bewegung.datumAbgang.anzeigeText) · \(bewegung.grund.rawValue)")
                        .font(.caption).foregroundColor(.secondary)
                    if let er = bewegung.erwarteteRueckgabe {
                        Text("Erwartet zurück: \(er.anzeigeText)")
                            .font(.caption)
                            .foregroundColor(bewegung.status == .ueberfaellig ? .red : .secondary)
                    }
                }
                Spacer()
                VStack(spacing: 6) {
                    if bewegung.stellvertretungRKId == nil {
                        Button("An Stellvertretung") { zeigeStellvertretung = true }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    Button("Zurückgegeben") { zeigeRueckgabe = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $zeigeStellvertretung) {
            StellvertretungZuweisenView(bewegung: bewegung)
        }
        .sheet(isPresented: $zeigeRueckgabe) {
            BewegungErfassenView(modus: .rueckgabe(bewegung))
        }
    }
}

// MARK: - Karte: Schlüssel bei zugeteilter RK (Normalzustand)

struct SchluesselBeiRKKarte: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var kunde: Kunde
    @State private var zeigeEinfordern = false
    @State private var zeigeStandort = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill").foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                if let rk = vm.zugeteilteReinigungskraft(kundenId: kunde.id) {
                    Text("Bei \(rk.name)").fontWeight(.medium).foregroundColor(.green)
                    Text("Normalzustand · \(kunde.standortText) wenn zurück im Büro")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Nicht zugeteilt").fontWeight(.medium).foregroundColor(.secondary)
                    Text(kunde.standortText).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                Button("Schlüssel einfordern") { zeigeEinfordern = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("Standort ändern") { zeigeStandort = true }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $zeigeEinfordern) {
            BewegungErfassenView(modus: .einfordern(vorausgewaehlt: kunde))
        }
        .sheet(isPresented: $zeigeStandort) {
            StandortFormular(typ: kunde.standortTyp, detail: kunde.standortDetail) { neuerTyp, neuesDetail in
                vm.standortAktualisieren(kundenId: kunde.id, typ: neuerTyp, detail: neuesDetail)
                zeigeStandort = false
            }
        }
        .onReceive(vm.$kunden) { liste in
            if let k = liste.first(where: { $0.id == kunde.id }) { kunde = k }
        }
    }
}

// MARK: - Stellvertretung zuweisen (Sheet)

struct StellvertretungZuweisenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let bewegung: Bewegung
    @State private var gewaehlteRK: Reinigungskraft?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stellvertretung zuweisen").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            Divider()
            Form {
                Section("Reinigungskraft") {
                    Picker("Stellvertretung", selection: $gewaehlteRK) {
                        Text("Bitte auswählen").tag(Optional<Reinigungskraft>(nil))
                        ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                            Text(r.name).tag(Optional(r))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Zuweisen") {
                    if let rk = gewaehlteRK {
                        vm.stellvertretungSetzen(bewegungId: bewegung.id, rkId: rk.id)
                        dismiss()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(gewaehlteRK == nil)
            }
            .padding()
        }
        .frame(width: 360, height: 220)
    }
}

// MARK: - Standort-Formular

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

    private var aufenthaltsort: String {
        if let rkId = bewegung.stellvertretungRKId { return vm.rkName(id: rkId) }
        return bewegung.istOffen ? "Im Büro" : "–"
    }

    var body: some View {
        HStack {
            Text(bewegung.datumAbgang.anzeigeText)
                .font(.caption).frame(width: 90, alignment: .leading)
            Text(aufenthaltsort)
                .font(.caption)
                .foregroundColor(bewegung.stellvertretungRKId != nil ? .orange : .secondary)
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
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var vorlage: Kunde?
    let onSpeichern: (Kunde) -> Void

    @State private var kundennummer = ""
    @State private var name = ""
    @State private var wohnort = ""
    @State private var zugeteilteRKId: Int64 = 0
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
                Section("Zugeteilte Reinigungskraft") {
                    Picker("Reinigungskraft", selection: $zugeteilteRKId) {
                        Text("Keine Zuteilung").tag(Int64(0))
                        ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                            Text(r.name).tag(r.id)
                        }
                    }
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
                    k.zugeteilteReinigungskraftId = zugeteilteRKId
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
        .frame(width: 420, height: 480)
        .onAppear {
            if let k = vorlage {
                kundennummer = k.kundennummer
                name = k.name
                wohnort = k.wohnort
                zugeteilteRKId = k.zugeteilteReinigungskraftId
                aktiv = k.aktiv
                notizen = k.notizen
            }
        }
    }
}
