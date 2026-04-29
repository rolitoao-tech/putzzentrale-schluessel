import SwiftUI

struct KundenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var ausgewaehlterKunde: Kunde?
    @State private var suchtext = ""
    @State private var nurImUmlauf = false
    @State private var zeigeNeuenKunden = false

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
        kundenListe
            .navigationTitle("Kunden")
            .toolbar {
                ToolbarItem {
                    Toggle(isOn: $nurImUmlauf) {
                        Label("Im Umlauf", systemImage: "arrow.left.arrow.right")
                    }
                    .toggleStyle(.button)
                    .help("Nur Schlüssel anzeigen, die nicht bei der zugeteilten RK sind")
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
            .onReceive(vm.$kunden) { liste in
                guard let sel = ausgewaehlterKunde else { return }
                ausgewaehlterKunde = liste.first { $0.id == sel.id }
            }
    }

    // MARK: - Kundenliste

    private var kundenListe: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Name, Kundennr., Wohnort", text: $suchtext).textFieldStyle(.plain)
                if !suchtext.isEmpty {
                    Button { suchtext = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                // Platz für Status-Punkt in den Zeilen (fix, nicht vertikal flexibel)
                Spacer().frame(width: 18)
                Text("Nr.").frame(width: 48, alignment: .leading)
                Text("Name").frame(minWidth: 80, alignment: .leading)
                Text("Wohnort").frame(minWidth: 60, alignment: .leading)
                Spacer(minLength: 4)
                Text("Standort").frame(minWidth: 90, alignment: .trailing)
            }
            .font(.caption).foregroundColor(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(gefiltert) { k in
                        KundenZeile(kunde: k)
                            .background(ausgewaehlterKunde?.id == k.id
                                ? Color.accentColor.opacity(0.15)
                                : Color(.controlBackgroundColor))
                            .contentShape(Rectangle())
                            .onTapGesture { ausgewaehlterKunde = k }
                        Divider().padding(.leading, 10)
                    }
                }
            }
            .background(Color(.controlBackgroundColor))
        }
    }
}

// MARK: - Listenzeile

struct KundenZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let kunde: Kunde

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(statusFarbe).frame(width: 8, height: 8)
                .padding(.trailing, 10)
            Text(kunde.kundennummer)
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(kunde.name).fontWeight(.medium)
                .frame(minWidth: 80, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(kunde.wohnort)
                .font(.caption).foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
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
            // Schlüssel eingefordert
            if let rkId = b.stellvertretungRKId {
                Label(vm.rkName(id: rkId), systemImage: "person.2.fill")
                    .font(.caption2).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12)).clipShape(Capsule())
            } else {
                Label(b.aufenthaltsText, systemImage: b.bueroAblage?.icon ?? "building.2.fill")
                    .font(.caption2).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12)).clipShape(Capsule())
            }
        } else if let rk = vm.zugeteilteReinigungskraft(kundenId: kunde.id) {
            // Normalzustand: bei zugeteilter RK
            Label(rk.name, systemImage: "person.fill")
                .font(.caption2).foregroundColor(.green)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.10)).clipShape(Capsule())
        } else {
            Label("Keine Zuteilung", systemImage: "questionmark.circle")
                .font(.caption2).foregroundColor(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.secondary.opacity(0.10)).clipShape(Capsule())
        }
    }
}

// MARK: - Kunden-Detailansicht

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
                            .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
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
                } label: { Image(systemName: "ellipsis.circle") }
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
                SchluesselBeiRKKarte(kunde: kunde)
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
                        Text("War bei").frame(minWidth: 90, alignment: .leading)
                        Text("Grund").frame(width: 110, alignment: .leading)
                        Text("Erwartet").frame(width: 85, alignment: .leading)
                        Text("Zurück").frame(width: 85, alignment: .leading)
                        Spacer(minLength: 4)
                        Text("Status").frame(width: 85, alignment: .trailing)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(bewegungen) { b in HistorieZeile(bewegung: b) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Schlüssel unterwegs (Bewegung offen)

struct SchluesselUnterwegsKarte: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let kunde: Kunde
    @State private var zeigeStellvertretung = false
    @State private var zeigeRueckgabe = false
    @State private var zeigeBearbeiten = false
    @State private var zeigeLoeschen = false

    private var aufenthaltsort: String {
        if let rkId = bewegung.stellvertretungRKId {
            return "Bei \(vm.rkName(id: rkId)) (Stellvertretung)"
        }
        return bewegung.aufenthaltsText
    }

    private var aufenthaltsIcon: String {
        if bewegung.stellvertretungRKId != nil { return "person.2.fill" }
        return bewegung.bueroAblage?.icon ?? "building.2.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: aufenthaltsIcon).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(aufenthaltsort).fontWeight(.medium).foregroundColor(.orange)
                Text("Eingefordert am \(bewegung.datumAbgang.anzeigeText) · \(bewegung.grund.rawValue)")
                    .font(.caption).foregroundColor(.secondary)
                if let er = bewegung.erwarteteRueckgabe {
                    Text("Erwartet zurück: \(er.anzeigeText)").font(.caption)
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
                Menu {
                    Button("Bearbeiten") { zeigeBearbeiten = true }
                    Divider()
                    Button("Bewegung löschen", role: .destructive) { zeigeLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain).controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $zeigeStellvertretung) { StellvertretungZuweisenView(bewegung: bewegung) }
        .sheet(isPresented: $zeigeRueckgabe) { BewegungErfassenView(modus: .rueckgabe(bewegung)) }
        .sheet(isPresented: $zeigeBearbeiten) { BewegungErfassenView(modus: .bearbeiten(bewegung)) }
        .confirmationDialog(
            "Bewegung löschen?",
            isPresented: $zeigeLoeschen,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { vm.bewegungLoeschen(id: bewegung.id) }
        } message: {
            Text("Der Schlüssel gilt danach wieder als beim Normalzustand (bei zugeteilter RK).")
        }
    }
}

// MARK: - Schlüssel bei RK (Normalzustand)

struct SchluesselBeiRKKarte: View {
    @EnvironmentObject var vm: AppViewModel
    let kunde: Kunde
    @State private var zeigeEinfordern = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill").foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                if let rk = vm.zugeteilteReinigungskraft(kundenId: kunde.id) {
                    Text("Bei \(rk.name)").fontWeight(.medium).foregroundColor(.green)
                    Text("Normalzustand – Schlüssel bei der zugeteilten Reinigungskraft")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Keine Reinigungskraft zugeteilt").fontWeight(.medium).foregroundColor(.secondary)
                    Text("Bitte Kunde bearbeiten und eine RK zuteilen")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if vm.zugeteilteReinigungskraft(kundenId: kunde.id) != nil {
                Button("Schlüssel einfordern") { zeigeEinfordern = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $zeigeEinfordern) {
            BewegungErfassenView(modus: .einfordern(vorausgewaehlt: kunde))
        }
    }
}

// MARK: - Stellvertretung zuweisen

struct StellvertretungZuweisenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let bewegung: Bewegung
    @State private var gewaehlteRK: Reinigungskraft?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("An Stellvertretung übergeben").font(.title3).fontWeight(.semibold)
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
                Button("Übergeben") {
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
        .frame(minWidth: 320, minHeight: 180)
    }
}

// MARK: - Historiezeile

struct HistorieZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    @State private var zeigeBearbeiten = false
    @State private var zeigeLoeschen = false

    private var warBei: String {
        if let rkId = bewegung.stellvertretungRKId { return vm.rkName(id: rkId) }
        return bewegung.aufenthaltsText
    }

    private var auditTooltip: String {
        guard !bewegung.erstelltVon.isEmpty else { return "Kein Audit-Eintrag vorhanden" }
        let datum = bewegung.erstelltAm.map { " am \($0.anzeigeText)" } ?? ""
        return "Erstellt von: \(bewegung.erstelltVon)\(datum)"
    }

    var body: some View {
        HStack {
            Text(bewegung.datumAbgang.anzeigeText)
                .font(.caption).frame(width: 90, alignment: .leading)
            Text(warBei)
                .font(.caption)
                .foregroundColor(bewegung.stellvertretungRKId != nil ? .orange : .secondary)
                .frame(minWidth: 90, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(bewegung.grund.rawValue)
                .font(.caption).frame(width: 110, alignment: .leading)
            Text(bewegung.erwarteteRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption).foregroundColor(.secondary).frame(width: 85, alignment: .leading)
            Text(bewegung.datumRueckgabe.map { $0.anzeigeText } ?? "–")
                .font(.caption).foregroundColor(.secondary).frame(width: 85, alignment: .leading)
            Spacer()
            Label(bewegung.status.bezeichnung, systemImage: bewegung.status.icon)
                .font(.caption).foregroundColor(bewegung.status.farbe)
                .frame(width: 85, alignment: .trailing)
            // Kontextmenü für Bearbeiten / Löschen
            Menu {
                if bewegung.istOffen {
                    Button("Bearbeiten") { zeigeBearbeiten = true }
                    Divider()
                }
                Button("Löschen", role: .destructive) { zeigeLoeschen = true }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.secondary).font(.caption)
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color(.controlBackgroundColor))
        .help(auditTooltip)
        .sheet(isPresented: $zeigeBearbeiten) {
            BewegungErfassenView(modus: .bearbeiten(bewegung))
        }
        .confirmationDialog("Eintrag löschen?", isPresented: $zeigeLoeschen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { vm.bewegungLoeschen(id: bewegung.id) }
        } message: {
            Text("Dieser Bewegungseintrag wird unwiderruflich gelöscht.")
        }
    }
}

// MARK: - Kunde-Formular

struct KundeFormular: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var vorlage: Kunde?
    let onSpeichern: (Kunde) -> Void

    @State private var kundennummer = ""
    @State private var name = ""
    @State private var wohnort = ""
    @State private var zugeteilteRKId: UUID? = nil
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
                        Text("Keine Zuteilung").tag(Optional<UUID>(nil))
                        ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                            Text(r.name).tag(Optional(r.id))
                        }
                    }
                }
                Section { Toggle("Aktiv", isOn: $aktiv) }
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
                    k.name         = name.trimmingCharacters(in: .whitespaces)
                    k.wohnort      = wohnort.trimmingCharacters(in: .whitespaces)
                    k.zugeteilteReinigungskraftId = zugeteilteRKId
                    k.aktiv   = aktiv
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
        .frame(minWidth: 380, minHeight: 400)
        .onAppear {
            if let k = vorlage {
                kundennummer   = k.kundennummer
                name           = k.name
                wohnort        = k.wohnort
                zugeteilteRKId = k.zugeteilteReinigungskraftId
                aktiv          = k.aktiv
                notizen        = k.notizen
            }
        }
    }
}
