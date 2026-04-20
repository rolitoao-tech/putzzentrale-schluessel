import SwiftUI

enum BewegungsModus {
    case abgang(vorausgewaehlt: Kunde? = nil)
    case rueckgabe(Bewegung)
}

struct BewegungErfassenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let modus: BewegungsModus

    // MARK: - Formular-Zustand (Abgang)

    @State private var gewaehlterKunde: Kunde?
    @State private var gewaehlteRK: Reinigungskraft?
    @State private var datumAbgang = Date()
    @State private var grund = BewegungGrund.einzelTermin
    @State private var setzeRueckgabedatum = true
    @State private var erwarteteRueckgabe = Date().addingTimeInterval(7 * 86400)
    @State private var poolEingetragen = false
    @State private var notizen = ""

    // MARK: - Formular-Zustand (Rückgabe)

    @State private var datumRueckgabe = Date()

    var body: some View {
        switch modus {
        case .abgang(let vorausgewaehlt):
            abgangFormular(vorausgewaehlt: vorausgewaehlt)
        case .rueckgabe(let b):
            rueckgabeFormular(bewegung: b)
        }
    }

    // MARK: - Abgang-Formular

    private func abgangFormular(vorausgewaehlt: Kunde?) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Abgang erfassen").font(.title3).fontWeight(.semibold)
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
                    } else {
                        Picker("Kunde", selection: $gewaehlterKunde) {
                            Text("Bitte auswählen").tag(Optional<Kunde>(nil))
                            ForEach(verfuegbareKunden) { k in
                                Text("\(k.kundennummer) – \(k.name)").tag(Optional(k))
                            }
                        }
                    }
                }

                Section("Reinigungskraft") {
                    Picker("Reinigungskraft", selection: $gewaehlteRK) {
                        Text("Bitte auswählen").tag(Optional<Reinigungskraft>(nil))
                        ForEach(vm.reinigungskraefte.filter(\.aktiv)) { r in
                            Text(r.name).tag(Optional(r))
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Datum Abgang", selection: $datumAbgang, displayedComponents: .date)
                    Picker("Grund", selection: $grund) {
                        ForEach(BewegungGrund.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    Toggle("Rückgabedatum setzen", isOn: $setzeRueckgabedatum)
                    if setzeRueckgabedatum {
                        DatePicker(
                            "Erwartete Rückgabe",
                            selection: $erwarteteRueckgabe,
                            in: datumAbgang...,
                            displayedComponents: .date
                        )
                    }
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
                Button("Abgang speichern") {
                    abgangSpeichern(vorausgewaehlt: vorausgewaehlt)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!abgangGueltig(vorausgewaehlt: vorausgewaehlt))
            }
            .padding()
        }
        .frame(width: 480, height: 540)
        .onAppear {
            if let k = vorausgewaehlt { gewaehlterKunde = k }
        }
    }

    // MARK: - Rückgabe-Formular

    private func rueckgabeFormular(bewegung: Bewegung) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rückgabe erfassen").font(.title3).fontWeight(.semibold)
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
                    LabeledContent("Reinigungskraft") {
                        Text(vm.rkName(id: bewegung.reinigungskraftId)).foregroundColor(.secondary)
                    }
                    LabeledContent("Abgang am") {
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
        .frame(width: 400, height: 300)
    }

    // MARK: - Hilfsmethoden

    private var verfuegbareKunden: [Kunde] {
        vm.kunden.filter { k in
            k.aktiv && vm.aktiveBewegung(kundenId: k.id) == nil
        }
    }

    private func abgangGueltig(vorausgewaehlt: Kunde?) -> Bool {
        let kundeOk = vorausgewaehlt != nil || gewaehlterKunde != nil
        return kundeOk && gewaehlteRK != nil
    }

    private func abgangSpeichern(vorausgewaehlt: Kunde?) {
        let kid = (vorausgewaehlt ?? gewaehlterKunde)!.id
        let rkid = gewaehlteRK!.id

        let bewegung = Bewegung(
            kundenId:           kid,
            datumAbgang:        datumAbgang,
            reinigungskraftId:  rkid,
            grund:              grund,
            erwarteteRueckgabe: setzeRueckgabedatum ? erwarteteRueckgabe : nil,
            poolEingetragen:    poolEingetragen,
            notizen:            notizen
        )

        Task {
            await vm.abgangErfassen(bewegung)
            await MainActor.run { dismiss() }
        }
    }
}
