import SwiftUI

// Generische Vorschau für CSV-Importe.
// Zeigt drei Bereiche: zu importierende Datensätze, übersprungene und Warnungen.
// `zeileBeschreibung` rendert pro Datensatz eine kompakte Beschriftung.
struct ImportVorschauView<T>: View {
    @Environment(\.dismiss) private var dismiss

    let titel: String
    let ergebnis: ImportErgebnis<T>
    let zeileBeschreibung: (T) -> String
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titel).font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        statKachel(label: "Neu", anzahl: ergebnis.neue.count, farbe: .green)
                        statKachel(label: "Übersprungen", anzahl: ergebnis.uebersprungen.count, farbe: .orange)
                        statKachel(label: "Warnungen", anzahl: ergebnis.warnungen.count, farbe: .yellow)
                    }

                    if !ergebnis.neue.isEmpty {
                        sektion(titel: "Wird importiert (\(ergebnis.neue.count))", farbe: .green) {
                            ForEach(Array(ergebnis.neue.enumerated()), id: \.offset) { _, item in
                                Text(zeileBeschreibung(item))
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if !ergebnis.uebersprungen.isEmpty {
                        sektion(titel: "Wird übersprungen (\(ergebnis.uebersprungen.count))", farbe: .orange) {
                            ForEach(Array(ergebnis.uebersprungen.enumerated()), id: \.offset) { _, paar in
                                HStack {
                                    Text(zeileBeschreibung(paar.0))
                                    Spacer()
                                    Text(paar.1).foregroundColor(.secondary)
                                }
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if !ergebnis.warnungen.isEmpty {
                        sektion(titel: "Warnungen (\(ergebnis.warnungen.count))", farbe: .yellow) {
                            ForEach(ergebnis.warnungen, id: \.self) { w in
                                Text(w).font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()
            HStack {
                Spacer()
                Button("Importieren (\(ergebnis.neue.count))") {
                    onImport()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(ergebnis.neue.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 640, minHeight: 520)
    }

    // MARK: - Bausteine

    private func statKachel(label: String, anzahl: Int, farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(anzahl)").font(.title).fontWeight(.bold).foregroundColor(farbe)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func sektion<C: View>(titel: String, farbe: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.headline).foregroundColor(farbe)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
