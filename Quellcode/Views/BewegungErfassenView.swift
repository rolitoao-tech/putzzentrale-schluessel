import SwiftUI

enum BewegungsModus {
    case einfordern(vorausgewaehlt: Kunde? = nil)
    case rueckgabe(Bewegung)
}

struct BewegungErfassenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let modus: BewegungsModus

    // MARK: - Formular-Zustand (Einfordern)

    @State private var gewaehlterKunde: Kunde?
    @State private var datumAbgang = Date()
    @State private var grund = BewegungGrund.einzelTermin
    @State private var setzeRueckgabedatum = true
    @State private var erwarteteRueckgabe = Date().addingTimeInterval(7 * 86400)
    @State private var mitStellvertretung = false
    @State private var gewaehlteStellvertretung: Reinigungskraft?
    @State private var poolEingetragen = false
    @State private var notizen = ""

    // MARK: - Formular-Zustand (Rückgabe)

    @State private var datumRueckgabe = Date()

    var body: some View {
        switch modus {
        case .einfordern(let vorausgewaehlt):
            einfordernFormular(vorausgewaehlt: vorausgewaehlt)
        case .rueckgabe(let b):
            rueckgabeFormular(bewegung: b)
        }
    }

    // MARK: - Einfordern-Formular

    private func einfordernFormular(vorausgewaehlt: Kunde?) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schlüssel einfordern").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                Section("Kunde") {
                    if let k = vorausgewaehlt {
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
                    DatePicker("Datum Einfordern", selection: $datumAbgang, displayedComponents: .date)
                    Picker("Grund", selection: $grund) {
                        ForEach(BewegungGrund.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    Toggle("Rückgabedatum setzen", isOn: $setzeRueckgabedatum)
                    if setzeRueckgabedatum {
                        DatePicker(
                            "Erwartet zurück",
                            selection: $erwarteteRueckgabe,
                            in: datumAbgang...,
                            displayedComponents: .date
                        )
                    }
                }

                Section("Stellvertretung") {
                    Toggle("Direkt an Stellvertretung", isOn: $mitStellvertretung)
                    if mitStellvertretung {
                        Picker("Reinigungskraft", selection: $gewaehlteStellvertretung) {
                            Text("Bitte auswählen").tag(Optional<Reinigungskraft>(nil))
                            ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                                Text(r.name).tag(Optional(r))
                            }
                        }
                    }
                }

                Section("CRM") {
                    Toggle("Im Pool (CRM) eingetragen", isOn: $poolEingetragen)
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
                    einfordernSpeichern(vorausgewaehlt: vorausgewaehlt)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!einfordernGueltig(vorausgewaehlt: vorausgewaehlt))
            }
            .padding()
        }
        .frame(width: 480, height: 560)
        .onAppear {
            if let k = vorausgewaehlt { gewaehlterKunde = k }
        }
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
                    if let rkId = bewegung.stellvertretungRKId {
                        LabeledContent("War bei") {
                            Text(vm.rkName(id: rkId)).foregroundColor(.secondary)
                        }
                    } else {
                        LabeledContent("War bei") {
                            Text("Im Büro").foregroundColor(.secondary)
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
        .frame(width: 400, height: 330)
    }

    // MARK: - Hilfsmethoden

    private var verfuegbareKunden: [Kunde] {
        vm.kunden.filter { k in
            k.aktiv && vm.aktiveBewegung(kundenId: k.id) == nil
        }
    }

    private func einfordernGueltig(vorausgewaehlt: Kunde?) -> Bool {
        let kundeOk = vorausgewaehlt != nil || gewaehlterKunde != nil
        let stellvertretungOk = !mitStellvertretung || gewaehlteStellvertretung != nil
        return kundeOk && stellvertretungOk
    }

    private func einfordernSpeichern(vorausgewaehlt: Kunde?) {
        let kid = (vorausgewaehlt ?? gewaehlterKunde)!.id

        let bewegung = Bewegung(
            kundenId:             kid,
            datumAbgang:          datumAbgang,
            grund:                grund,
            stellvertretungRKId:  mitStellvertretung ? gewaehlteStellvertretung?.id : nil,
            erwarteteRueckgabe:   setzeRueckgabedatum ? erwarteteRueckgabe : nil,
            poolEingetragen:      poolEingetragen,
            notizen:              notizen
        )

        Task {
            await vm.abgangErfassen(bewegung)
            await MainActor.run { dismiss() }
        }
    }
}
