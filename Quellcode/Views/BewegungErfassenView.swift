import SwiftUI

// Unterscheidung ob Abgang oder Rückgabe erfasst wird
enum BewegungsModus {
    case abgang
    case rueckgabe(Bewegung)  // bestehende offene Bewegung
}

struct BewegungErfassenView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let modus: BewegungsModus
    // Wenn aus SchlüsselDetail aufgerufen, ist der Schlüssel schon bekannt
    var vorausgewaehlterSchluessel: Schluessel? = nil

    // MARK: - Formular-Zustand (Abgang)

    @State private var gewaehlterSchluessel: Schluessel?
    @State private var gewaehlterPutzfrau: Putzfrau?
    @State private var datumAbgang = Date()
    @State private var grund = BewegungGrund.einzelTermin
    @State private var setzeRueckgabedatum = true
    @State private var erwarteteRueckgabe = Date().addingTimeInterval(7 * 86400)
    @State private var notizen = ""

    // MARK: - Formular-Zustand (Rückgabe)

    @State private var datumRueckgabe = Date()

    // MARK: - Mehrfach-Abgang (alle Schlüssel einer Putzfrau zurück)

    @State private var mehrfachModus = false
    @State private var gewaehlteSchluessel: Set<Int64> = []

    // Fehlerbehandlung
    @State private var fehlermeldung: String?

    var body: some View {
        switch modus {
        case .abgang:
            abgangFormular
        case .rueckgabe(let b):
            rueckgabeFormular(bewegung: b)
        }
    }

    // MARK: - Abgang-Formular

    private var abgangFormular: some View {
        VStack(spacing: 0) {
            // Titel-Leiste
            HStack {
                Text("Abgang erfassen")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                // Schlüssel-Auswahl
                Section("Schlüssel") {
                    if let vs = vorausgewaehlterSchluessel {
                        LabeledContent("Schlüssel") {
                            Text(vs.bezeichnung).foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Schlüssel", selection: $gewaehlterSchluessel) {
                            Text("Bitte auswählen").tag(Optional<Schluessel>(nil))
                            ForEach(verfuegbareSchluessel) { s in
                                Text("\(s.bezeichnung) – \(vm.kundeName(id: s.kundeId))")
                                    .tag(Optional(s))
                            }
                        }
                    }
                }

                // Empfängerin
                Section("Empfängerin") {
                    Picker("Putzfrau", selection: $gewaehlterPutzfrau) {
                        Text("Bitte auswählen").tag(Optional<Putzfrau>(nil))
                        ForEach(vm.putzfrauen.filter { $0.status != .inaktiv }) { p in
                            HStack {
                                Image(systemName: p.status.icon)
                                    .foregroundColor(p.status.farbe)
                                Text(p.name)
                            }
                            .tag(Optional(p))
                        }
                    }
                }

                // Bewegungsdaten
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
                }

                // Notizen
                Section("Notizen (optional)") {
                    TextEditor(text: $notizen)
                        .frame(height: 60)
                }

                // Fehlermeldung
                if let fehler = fehlermeldung {
                    Section {
                        Label(fehler, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Aktions-Leiste
            HStack {
                Spacer()
                Button("Abgang speichern") {
                    abgangSpeichern()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!abgangGueltig)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Rückgabe-Formular

    private func rueckgabeFormular(bewegung: Bewegung) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rückgabe erfassen")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                Section("Bewegung") {
                    LabeledContent("Schlüssel") {
                        Text(vm.schluesselName(id: bewegung.schluesselId))
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Putzfrau") {
                        Text(vm.putzfrauName(id: bewegung.putzfrauId))
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Abgang am") {
                        Text(bewegung.datumAbgang.anzeigeText)
                            .foregroundColor(.secondary)
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
        .frame(width: 400, height: 320)
    }

    // MARK: - Hilfs-Methoden

    // Nur Schlüssel anzeigen, die gerade im Büro sind (keine offene Bewegung)
    private var verfuegbareSchluessel: [Schluessel] {
        vm.schluessel.filter { s in
            !s.verloren && vm.aktuellerInhaber(schluesselId: s.id) == nil
        }
    }

    private var abgangGueltig: Bool {
        let schluesselOk = vorausgewaehlterSchluessel != nil || gewaehlterSchluessel != nil
        return schluesselOk && gewaehlterPutzfrau != nil
    }

    private func abgangSpeichern() {
        guard abgangGueltig else { return }

        let sid = (vorausgewaehlterSchluessel ?? gewaehlterSchluessel)!.id
        let pid = gewaehlterPutzfrau!.id

        let bewegung = Bewegung(
            schluesselId:       sid,
            datumAbgang:        datumAbgang,
            putzfrauId:         pid,
            grund:              grund,
            erwarteteRueckgabe: setzeRueckgabedatum ? erwarteteRueckgabe : nil,
            notizen:            notizen
        )

        Task {
            await vm.abgangErfassen(bewegung)
            await MainActor.run { dismiss() }
        }
    }
}
