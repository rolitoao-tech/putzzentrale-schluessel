import SwiftUI

// Fokus-Hinweis für die Detail-Ansicht: zu welcher Sektion soll gescrollt werden?
enum RKFokus: String, Hashable {
    case beiIhr         = "bei-ihr"
    case unterwegs      = "unterwegs"
    case stellvertretung = "stellvertretung"
}

struct ReinigungskraefteView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var ausgewaehlt: Reinigungskraft?
    var onZahlenklick: ((Reinigungskraft, RKFokus) -> Void)? = nil
    @State private var zeigeNeueForm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header-Zeile
            HStack(spacing: 0) {
                Spacer().frame(width: 18)
                Text("Name")
                    .frame(minWidth: 80, alignment: .leading)
                Spacer(minLength: 4)
                Text("Bei ihr")
                    .frame(width: 55, alignment: .trailing)
                Text("Unterwegs")
                    .frame(width: 75, alignment: .trailing)
                Text("Stellv.")
                    .frame(width: 55, alignment: .trailing)
            }
            .font(.caption).foregroundColor(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.reinigungskraefte) { r in
                        Button {
                            ausgewaehlt = r
                        } label: {
                            ReinigungskraftZeile(rk: r, onZahlenklick: { fokus in
                                onZahlenklick?(r, fokus)
                            })
                            .background(ausgewaehlt?.id == r.id
                                ? Color.accentColor.opacity(0.15)
                                : Color(.controlBackgroundColor))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 10)
                    }
                }
            }
            .background(Color(.controlBackgroundColor))
        }
        .navigationTitle("Reinigungskräfte")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeNeueForm = true } label: {
                    Label("Neue Reinigungskraft", systemImage: "plus")
                }
            }
            // Temporär: Demo-Daten für Entwicklung. Wird vor Auslieferung entfernt.
            ToolbarItem {
                Button {
                    vm.demoDatenErzeugen()
                } label: {
                    Label("Demo-Daten", systemImage: "wand.and.stars")
                }
                .help("Erzeugt 5 RKs + 20 Demo-Kunden mit gemischten Bewegungen")
            }
        }
        .sheet(isPresented: $zeigeNeueForm) {
            ReinigungskraftFormular(vorlage: nil) { r in
                vm.rkHinzufuegen(r)
                zeigeNeueForm = false
            }
        }
    }
}

// MARK: - Listenzeile mit Kennzahlen

struct ReinigungskraftZeile: View {
    @EnvironmentObject var vm: AppViewModel
    let rk: Reinigungskraft
    var onZahlenklick: ((RKFokus) -> Void)? = nil

    // Eigene Kunden ohne aktive Bewegung — Schlüssel ist normal bei ihr
    private var anzahlBeiIhr: Int {
        vm.zugeteilteKunden(rkId: rk.id).filter {
            vm.aktiveBewegung(kundenId: $0.id) == nil
        }.count
    }

    // Eigene Kunden mit aktiver Bewegung — Schlüssel ist gerade weg (Büro/Stellv./unterwegs)
    private var anzahlUnterwegs: Int {
        vm.zugeteilteKunden(rkId: rk.id).filter {
            vm.aktiveBewegung(kundenId: $0.id) != nil
        }.count
    }

    // Fremde Schlüssel die GERADE als Stellvertretung bei ihr liegen
    private var anzahlStellvertretung: Int {
        vm.bewegungen(fuerStellvertretung: rk.id, nurOffen: true).count
    }

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(rk.aktiv ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .padding(.trailing, 10)

            HStack(spacing: 6) {
                Text(rk.name).fontWeight(.medium).lineLimit(1)
                if !rk.aktiv {
                    Text("Inaktiv").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer(minLength: 4)

            Button { onZahlenklick?(.beiIhr) } label: {
                Text("\(anzahlBeiIhr)")
                    .font(.callout)
                    .foregroundColor(anzahlBeiIhr > 0 ? .primary : .secondary)
                    .frame(width: 55, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help("Eigene Schlüssel die aktuell bei \(rk.name) sind")

            Button { onZahlenklick?(.unterwegs) } label: {
                Text("\(anzahlUnterwegs)")
                    .font(.callout)
                    .foregroundColor(anzahlUnterwegs > 0 ? .orange : .secondary)
                    .frame(width: 75, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help("Eigene Schlüssel die gerade unterwegs sind")

            Button { onZahlenklick?(.stellvertretung) } label: {
                Text("\(anzahlStellvertretung)")
                    .font(.callout)
                    .foregroundColor(anzahlStellvertretung > 0 ? .orange : .secondary)
                    .frame(width: 55, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help("Fremde Schlüssel die als Stellvertretung bei \(rk.name) liegen")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .opacity(rk.aktiv ? 1 : 0.6)
    }
}

// MARK: - Detailansicht

struct ReinigungskraftDetail: View {
    @EnvironmentObject var vm: AppViewModel
    let rk: Reinigungskraft
    var initialFokus: RKFokus? = nil
    var onAktualisiert: ((Reinigungskraft) -> Void)? = nil

    @State private var zeigeAlleZurueck = false
    @State private var zeigeLoeschen = false
    @State private var zeigeBearbeiten = false
    @State private var hervorgehoben: RKFokus?

    private var zugeteilteKunden: [Kunde] {
        vm.zugeteilteKunden(rkId: rk.id)
    }

    private var kundenBeiIhr: [Kunde] {
        zugeteilteKunden.filter { vm.aktiveBewegung(kundenId: $0.id) == nil }
    }

    private var kundenUnterwegs: [Kunde] {
        zugeteilteKunden.filter { vm.aktiveBewegung(kundenId: $0.id) != nil }
    }

    private var stellvertretungenOffen: [Bewegung] {
        vm.bewegungen(fuerStellvertretung: rk.id, nurOffen: true)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kopfbereich

                    stellvertretungsSektion.id(RKFokus.stellvertretung.rawValue)
                    kundenUnterwegsSektion.id(RKFokus.unterwegs.rawValue)
                    kundenBeiIhrSektion.id(RKFokus.beiIhr.rawValue)
                }
                .padding(20)
            }
            .onAppear {
                if let f = initialFokus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation { proxy.scrollTo(f.rawValue, anchor: .top) }
                        flashHighlight(f)
                    }
                }
            }
            .onChange(of: initialFokus) { neu in
                guard let f = neu else { return }
                withAnimation { proxy.scrollTo(f.rawValue, anchor: .top) }
                flashHighlight(f)
            }
        }
        .confirmationDialog(
            "Alle Stellvertreter-Schlüssel von \(rk.name) zurück?",
            isPresented: $zeigeAlleZurueck,
            titleVisibility: .visible
        ) {
            Button("Alle zurück") { vm.alleStellvertretungsSchluesselZurueck(vonRKId: rk.id) }
        } message: {
            Text("\(stellvertretungenOffen.count) offene Stellvertretung(en) werden als zurückgegeben markiert.")
        }
        .confirmationDialog(
            "Reinigungskraft «\(rk.name)» löschen?",
            isPresented: $zeigeLoeschen,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { vm.rkLoeschen(id: rk.id) }
        } message: {
            Text("Zugeteilte Kunden verlieren die Zuteilung. Bewegungen bleiben erhalten.")
        }
        .sheet(isPresented: $zeigeBearbeiten) {
            ReinigungskraftFormular(vorlage: rk) { r in
                vm.rkAktualisieren(r)
                onAktualisiert?(r)
                zeigeBearbeiten = false
            }
        }
    }

    // Sektion-Titel kurz hervorheben (visuelles Feedback nach Drilldown)
    private func flashHighlight(_ f: RKFokus) {
        withAnimation(.easeIn(duration: 0.15)) { hervorgehoben = f }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                if hervorgehoben == f { hervorgehoben = nil }
            }
        }
    }

    private var kopfbereich: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rk.name).font(.title2).fontWeight(.bold)
                    if !rk.aktiv {
                        Text("Inaktiv").font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 12) {
                    Label("\(zugeteilteKunden.count) zugeteilte Kunden", systemImage: "key.fill")
                        .font(.caption).foregroundColor(.secondary)
                    if !stellvertretungenOffen.isEmpty {
                        Label("\(stellvertretungenOffen.count) Stellvertretung(en)", systemImage: "person.2.fill")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
            HStack {
                Button("Bearbeiten") { zeigeBearbeiten = true }.buttonStyle(.bordered)
                if !stellvertretungenOffen.isEmpty {
                    Button("Alle zurück") { zeigeAlleZurueck = true }
                        .buttonStyle(.bordered).foregroundColor(.orange)
                }
                Menu {
                    Button("Löschen", role: .destructive) { zeigeLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var stellvertretungsSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktuell als Stellvertretung (\(stellvertretungenOffen.count))")
                .font(.headline)
                .foregroundColor(stellvertretungenOffen.isEmpty ? .secondary : .orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(hervorgehoben == .stellvertretung ? Color.orange.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if stellvertretungenOffen.isEmpty {
                Text("Keine fremden Schlüssel als Stellvertretung bei \(rk.name).")
                    .font(.caption).foregroundColor(.secondary)
            } else {
            VStack(spacing: 1) {
                ForEach(stellvertretungenOffen) { b in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.kundeName(id: b.kundenId)).fontWeight(.medium)
                            if let k = vm.kunde(id: b.kundenId) {
                                Text("Nr. \(k.kundennummer)").font(.caption2).foregroundColor(.secondary)
                            }
                            // Zeige zugeteilte RK – macht deutlich, wessen Kunde das ist
                            if let assignedRK = vm.zugeteilteReinigungskraft(kundenId: b.kundenId) {
                                Text("Zugeteilt an: \(assignedRK.name)")
                                    .font(.caption2).foregroundColor(.green.opacity(0.8))
                            }
                        }
                        .frame(minWidth: 180, alignment: .leading)
                        Text(b.grund.rawValue).font(.caption).foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        if let er = b.erwarteteRueckgabe {
                            Text(er.anzeigeText)
                                .font(.caption)
                                .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                        }
                        Image(systemName: b.status.icon)
                            .foregroundColor(b.status.farbe).font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // Schlüssel die GERADE bei der RK sind (Normalzustand, keine offene Bewegung)
    private var kundenBeiIhrSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schlüssel bei \(rk.name) (\(kundenBeiIhr.count))")
                .font(.headline).foregroundColor(.green.opacity(0.9))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(hervorgehoben == .beiIhr ? Color.green.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if kundenBeiIhr.isEmpty {
                Text("Keine Schlüssel aktuell bei \(rk.name).")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                VStack(spacing: 1) {
                    HStack {
                        Text("Nr.").frame(width: 60, alignment: .leading)
                        Text("Name").frame(minWidth: 150, alignment: .leading)
                        Text("Wohnort").frame(minWidth: 100, alignment: .leading)
                        Spacer()
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(kundenBeiIhr) { k in
                        HStack {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text(k.kundennummer).font(.caption).foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(k.name).frame(minWidth: 150, alignment: .leading)
                            Text(k.wohnort).font(.caption).foregroundColor(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(.controlBackgroundColor))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // Schlüssel die aktuell unterwegs sind (Büro/Stellvertretung/in Bewegung)
    private var kundenUnterwegsSektion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schlüssel unterwegs (\(kundenUnterwegs.count))")
                .font(.headline).foregroundColor(kundenUnterwegs.isEmpty ? .secondary : .orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(hervorgehoben == .unterwegs ? Color.orange.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if kundenUnterwegs.isEmpty {
                Text("Alle Schlüssel sind bei \(rk.name).")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                VStack(spacing: 1) {
                    HStack {
                        Text("Nr.").frame(width: 60, alignment: .leading)
                        Text("Name").frame(minWidth: 130, alignment: .leading)
                        Text("Aktueller Standort").frame(minWidth: 130, alignment: .leading)
                        Spacer()
                        Text("Erwartet").frame(width: 90, alignment: .trailing)
                        Text("Status").frame(width: 24, alignment: .trailing)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))

                    ForEach(kundenUnterwegs) { k in
                        if let b = vm.aktiveBewegung(kundenId: k.id) {
                            HStack {
                                Circle().fill(b.status.farbe).frame(width: 7, height: 7)
                                Text(k.kundennummer).font(.caption).foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text(k.name).frame(minWidth: 130, alignment: .leading)
                                let ort = b.stellvertretungRKId != nil
                                    ? "Bei \(vm.rkName(id: b.stellvertretungRKId!))"
                                    : b.aufenthaltsText
                                Text(ort)
                                    .font(.caption)
                                    .foregroundColor(b.stellvertretungRKId != nil ? .orange : .secondary)
                                    .frame(minWidth: 130, alignment: .leading)
                                Spacer()
                                if let er = b.erwarteteRueckgabe {
                                    Text(er.anzeigeText)
                                        .font(.caption)
                                        .foregroundColor(b.status == .ueberfaellig ? .red : .secondary)
                                        .frame(width: 90, alignment: .trailing)
                                } else {
                                    Text("–").font(.caption).foregroundColor(.secondary)
                                        .frame(width: 90, alignment: .trailing)
                                }
                                Image(systemName: b.status.icon)
                                    .foregroundColor(b.status.farbe).font(.caption)
                                    .frame(width: 24, alignment: .trailing)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color(.controlBackgroundColor))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Formular

struct ReinigungskraftFormular: View {
    @Environment(\.dismiss) private var dismiss

    var vorlage: Reinigungskraft?
    let onSpeichern: (Reinigungskraft) -> Void

    @State private var name = ""
    @State private var aktiv = true
    @State private var notizen = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vorlage == nil ? "Neue Reinigungskraft" : "Reinigungskraft bearbeiten")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("Name") {
                    TextField("Name", text: $name)
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
                    var r = vorlage ?? Reinigungskraft()
                    r.name = name.trimmingCharacters(in: .whitespaces)
                    r.aktiv = aktiv
                    r.notizen = notizen
                    onSpeichern(r)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 320, minHeight: 280)
        .onAppear {
            if let r = vorlage {
                name = r.name; aktiv = r.aktiv; notizen = r.notizen
            }
        }
    }
}
