import SwiftUI

enum BewegungsModus {
    case einfordern(vorausgewaehlt: Kunde? = nil)
    case bearbeiten(Bewegung)
    case rueckgabe(Bewegung)
}

private enum AblageWahl: String, CaseIterable {
    case safe            = "Safe"
    case dossier         = "Dossier"
    case stellvertretung = "Stellvertretung"
    case anKunde         = "An Kunde"

    var icon: String {
        switch self {
        case .safe:            return "lock.fill"
        case .dossier:         return "folder.fill"
        case .stellvertretung: return "person.2.fill"
        case .anKunde:         return "person.crop.circle.badge.checkmark"
        }
    }
}

struct BewegungErfassenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let modus: BewegungsModus

    @State private var gewaehlterKunde: Kunde?
    @State private var datumAbgang = Date()
    @State private var grund = BewegungGrund.einzelTermin
    @State private var ablageWahl: AblageWahl = .safe
    @State private var hakenNr = ""
    @State private var dossierKuerzel = ""
    @State private var gewaehlteStellvertretung: Reinigungskraft?
    @State private var setzeRueckgabedatum = true
    @State private var erwarteteRueckgabe = Date().addingTimeInterval(7 * 86400)
    @State private var bereitsZurueck = false
    @State private var datumRueckgabe = Date()
    @State private var poolEingetragen = false
    @State private var notizen = ""
    @State private var zeigeVertragsendeBestaetigung = false

    var body: some View {
        switch modus {
        case .einfordern(let vorausgewaehlt):
            einfordernFormular(vorausgewaehlt: vorausgewaehlt, bestehendesBewegung: nil)
        case .bearbeiten(let b):
            einfordernFormular(vorausgewaehlt: nil, bestehendesBewegung: b)
        case .rueckgabe(let b):
            rueckgabeFormular(bewegung: b)
        }
    }

    // MARK: - Einfordern / Bearbeiten

    private func einfordernFormular(vorausgewaehlt: Kunde?, bestehendesBewegung: Bewegung?) -> some View {
        let istBearbeiten = bestehendesBewegung != nil
        let titel = istBearbeiten ? "Bewegung bearbeiten" : "Schlüssel einfordern"

        return VStack(spacing: 0) {
            HStack {
                Text(titel).font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                Section("Kunde") {
                    if let b = bestehendesBewegung {
                        LabeledContent("Kunde") {
                            Text(vm.kundeName(id: b.kundenId)).foregroundColor(.secondary)
                        }
                    } else if let k = vorausgewaehlt {
                        LabeledContent("Kunde") {
                            Text("\(k.name) (Nr. \(k.kundennummer))").foregroundColor(.secondary)
                        }
                        if let rk = vm.zugeteilteReinigungskraft(kundenId: k.id) {
                            LabeledContent("Zugeteilte RK") {
                                Text(rk.name).foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Picker("Kunde", selection: $gewaehlterKunde) {
                            Text("Bitte auswählen").tag(Optional<Kunde>(nil))
                            ForEach(verfuegbareKunden) { k in
                                Text("\(k.kundennummer) – \(k.name)").tag(Optional(k))
                            }
                        }
                    }
                }

                Section("Details") {
                    DatePicker(
                        ablageWahl == .anKunde ? "Übergabedatum" : "Datum Einfordern",
                        selection: $datumAbgang,
                        displayedComponents: .date
                    )
                    if ablageWahl != .anKunde {
                        Picker("Grund", selection: $grund) {
                            ForEach(BewegungGrund.allCases, id: \.self) { g in
                                Text(g.rawValue).tag(g)
                            }
                        }
                        Toggle("Erwartetes Rückgabedatum", isOn: $setzeRueckgabedatum)
                        if setzeRueckgabedatum {
                            DatePicker(
                                "Erwartet zurück",
                                selection: $erwarteteRueckgabe,
                                in: datumAbgang...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                Section("Ablage") {
                    Picker("Ablageort", selection: $ablageWahl) {
                        ForEach(verfuegbareAblagen(istBearbeiten: istBearbeiten), id: \.self) { w in
                            Label(w.rawValue, systemImage: w.icon).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch ablageWahl {
                    case .safe:
                        TextField("Haken-Nr. (1–48)", text: $hakenNr)
                    case .dossier:
                        TextField("Kürzel / Bezeichnung", text: $dossierKuerzel)
                    case .stellvertretung:
                        Picker("Reinigungskraft", selection: $gewaehlteStellvertretung) {
                            Text("Bitte auswählen").tag(Optional<Reinigungskraft>(nil))
                            ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                                Text(r.name).tag(Optional(r))
                            }
                        }
                    case .anKunde:
                        Label(
                            "Schlüssel geht endgültig an den Kunde. Kunde wird inaktiv.",
                            systemImage: "info.circle"
                        )
                        .font(.caption).foregroundColor(.secondary)
                    }
                }

                // Historische Erfassung: Rückgabe bereits erfolgt
                // Bei „An Kunde" entfällt diese Sektion — die Bewegung wird automatisch geschlossen.
                if ablageWahl != .anKunde {
                    Section("Rückgabe") {
                        Toggle("Schlüssel bereits zurückgegeben", isOn: $bereitsZurueck)
                        if bereitsZurueck {
                            DatePicker(
                                "Datum Rückgabe",
                                selection: $datumRueckgabe,
                                in: datumAbgang...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                Section {
                    Toggle(isOn: $poolEingetragen) {
                        HStack(spacing: 6) {
                            Text(poolLabel)
                            if !poolEingetragen {
                                Text("(Pflichtfeld)")
                                    .font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("CRM")
                }

                Section {
                    TextEditor(text: $notizen).frame(height: 60)
                } header: {
                    HStack(spacing: 6) {
                        Text(ablageWahl == .anKunde ? "Notiz" : "Notizen")
                        if ablageWahl == .anKunde && !notizGueltigFuerVertragsende {
                            Text("(Pflichtfeld)").font(.caption).foregroundColor(.red)
                        } else if ablageWahl != .anKunde {
                            Text("(optional)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let b = bestehendesBewegung {
                    Button("Bewegung löschen") {
                        vm.bewegungLoeschen(id: b.id)
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button(ablageWahl == .anKunde ? "Vertrag beenden" : "Speichern") {
                    if ablageWahl == .anKunde && bestehendesBewegung == nil {
                        zeigeVertragsendeBestaetigung = true
                    } else {
                        speichern(vorausgewaehlt: vorausgewaehlt, bestehendesBewegung: bestehendesBewegung)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!formularGueltig(vorausgewaehlt: vorausgewaehlt, bestehendesBewegung: bestehendesBewegung))
            }
            .padding()
        }
        .frame(minWidth: 440, minHeight: 560)
        .onAppear { vorbefuellen(vorausgewaehlt: vorausgewaehlt, bewegung: bestehendesBewegung) }
        .confirmationDialog(
            "Vertrag beenden?",
            isPresented: $zeigeVertragsendeBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Vertrag beenden", role: .destructive) {
                speichern(vorausgewaehlt: vorausgewaehlt, bestehendesBewegung: bestehendesBewegung)
            }
        } message: {
            Text("Der Schlüssel wird endgültig an den Kunde übergeben und der Kunde wird inaktiv. Diese Aktion lässt sich nur über «Reaktivieren» rückgängig machen.")
        }
    }

    // Beim Bearbeiten ist „An Kunde" nicht erlaubt — das Vertragsende ist ein eigener
    // Workflow, kein Edit-Pfad (siehe Lücke H in Prozesslogik.md).
    private func verfuegbareAblagen(istBearbeiten: Bool) -> [AblageWahl] {
        istBearbeiten ? AblageWahl.allCases.filter { $0 != .anKunde } : AblageWahl.allCases
    }

    private var poolLabel: String {
        ablageWahl == .anKunde ? "Im CRM ausgetragen" : "Im Pool (CRM) eingetragen"
    }

    private var notizGueltigFuerVertragsende: Bool {
        !notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Rückgabe-Formular

    private func rueckgabeFormular(bewegung: Bewegung) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schlüssel zurückgegeben").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                Section("Bewegung") {
                    LabeledContent("Kunde") {
                        Text(vm.kundeName(id: bewegung.kundenId)).foregroundColor(.secondary)
                    }
                    LabeledContent("War bei") {
                        if let rkId = bewegung.stellvertretungRKId {
                            Text(vm.rkName(id: rkId)).foregroundColor(.secondary)
                        } else {
                            Text(bewegung.aufenthaltsText).foregroundColor(.secondary)
                        }
                    }
                    if let rk = vm.zugeteilteReinigungskraft(kundenId: bewegung.kundenId) {
                        LabeledContent("Zurück an") {
                            Text(rk.name).foregroundColor(.green)
                        }
                    }
                    LabeledContent("Eingefordert am") {
                        Text(bewegung.datumAbgang.anzeigeText).foregroundColor(.secondary)
                    }
                }

                Section("Rückgabe") {
                    DatePicker(
                        "Datum Rückgabe",
                        selection: $datumRueckgabe,
                        in: bewegung.datumAbgang...,
                        displayedComponents: .date
                    )
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Rückgabe bestätigen") {
                    vm.rueckgabeEintragen(bewegungId: bewegung.id, datum: datumRueckgabe)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 360, minHeight: 300)
    }

    // MARK: - Hilfsmethoden

    private var verfuegbareKunden: [Kunde] {
        vm.kunden.filter { k in
            k.aktiv && vm.aktiveBewegung(kundenId: k.id) == nil
        }
    }

    private func formularGueltig(vorausgewaehlt: Kunde?, bestehendesBewegung: Bewegung?) -> Bool {
        let kundeOk = bestehendesBewegung != nil || vorausgewaehlt != nil || gewaehlterKunde != nil
        let ablageOk: Bool
        switch ablageWahl {
        case .stellvertretung: ablageOk = gewaehlteStellvertretung != nil
        case .anKunde:         ablageOk = notizGueltigFuerVertragsende
        case .safe, .dossier:  ablageOk = true
        }
        return kundeOk && ablageOk && poolEingetragen
    }

    private func vorbefuellen(vorausgewaehlt: Kunde?, bewegung: Bewegung?) {
        if let k = vorausgewaehlt { gewaehlterKunde = k }
        guard let b = bewegung else { return }
        datumAbgang = b.datumAbgang
        grund = b.grund
        if let rkId = b.stellvertretungRKId {
            ablageWahl = .stellvertretung
            gewaehlteStellvertretung = vm.reinigungskraft(id: rkId)
        } else if let ablage = b.bueroAblage {
            ablageWahl = ablage == .safe ? .safe : .dossier
            hakenNr = ablage == .safe ? b.bueroAblageDetail : ""
            dossierKuerzel = ablage == .dossier ? b.bueroAblageDetail : ""
        }
        if let er = b.erwarteteRueckgabe {
            setzeRueckgabedatum = true
            erwarteteRueckgabe = er
        } else {
            setzeRueckgabedatum = false
        }
        if let dr = b.datumRueckgabe {
            bereitsZurueck = true
            datumRueckgabe = dr
        }
        poolEingetragen = b.poolEingetragen
        notizen = b.notizen
    }

    private func speichern(vorausgewaehlt: Kunde?, bestehendesBewegung: Bewegung?) {
        let kundenId: UUID
        if let b = bestehendesBewegung {
            kundenId = b.kundenId
        } else {
            kundenId = (vorausgewaehlt ?? gewaehlterKunde)!.id
        }

        let stv: UUID?
        let ablage: BueroAblage?
        let ablageDetail: String
        switch ablageWahl {
        case .stellvertretung:
            stv = gewaehlteStellvertretung?.id
            ablage = nil; ablageDetail = ""
        case .safe:
            stv = nil; ablage = .safe
            ablageDetail = hakenNr.trimmingCharacters(in: .whitespaces)
        case .dossier:
            stv = nil; ablage = .dossier
            ablageDetail = dossierKuerzel.trimmingCharacters(in: .whitespaces)
        case .anKunde:
            stv = nil; ablage = nil; ablageDetail = ""
        }

        let istVertragsende = ablageWahl == .anKunde

        var b = bestehendesBewegung ?? Bewegung()
        b.kundenId            = kundenId
        b.datumAbgang         = datumAbgang
        b.grund               = grund
        b.stellvertretungRKId = stv
        b.bueroAblage         = ablage
        b.bueroAblageDetail   = ablageDetail
        b.erwarteteRueckgabe  = istVertragsende ? nil : (setzeRueckgabedatum ? erwarteteRueckgabe : nil)
        b.datumRueckgabe      = istVertragsende ? datumAbgang : (bereitsZurueck ? datumRueckgabe : nil)
        b.endgueltigeUebergabeAnKunde = istVertragsende
        b.poolEingetragen     = poolEingetragen
        b.notizen             = notizen

        if bestehendesBewegung != nil {
            vm.bewegungAktualisieren(b)
            dismiss()
        } else if istVertragsende {
            Task {
                await vm.vertragsendeAusEinfordern(b)
                await MainActor.run { dismiss() }
            }
        } else {
            Task {
                await vm.abgangErfassen(b)
                await MainActor.run { dismiss() }
            }
        }
    }
}
