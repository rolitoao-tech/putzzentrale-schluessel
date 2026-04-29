import SwiftUI

// Read-only Historie aller abgeschlossenen Schlüsselbewegungen.
// Filter nach Zeitraum; Auswahl zeigt rechts den zugehörigen Kunden.
struct HistorieView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var auswahl: Bewegung?
    @State private var zeitraum: Zeitraum = .tage30

    enum Zeitraum: String, CaseIterable, Identifiable {
        case tage30  = "30 Tage"
        case tage90  = "90 Tage"
        case tage365 = "1 Jahr"
        case alle    = "Alle"

        var id: String { rawValue }

        var cutoff: Date? {
            let kalender = Calendar.current
            switch self {
            case .tage30:  return kalender.date(byAdding: .day,  value: -30,  to: Date())
            case .tage90:  return kalender.date(byAdding: .day,  value: -90,  to: Date())
            case .tage365: return kalender.date(byAdding: .year, value: -1,   to: Date())
            case .alle:    return nil
            }
        }
    }

    private var historie: [Bewegung] {
        let cutoff = zeitraum.cutoff
        return vm.alleBewegungen
            .filter { b in
                guard let zurueck = b.datumRueckgabe else { return false }
                if let c = cutoff { return zurueck >= c }
                return true
            }
            .sorted { ($0.datumRueckgabe ?? .distantPast) > ($1.datumRueckgabe ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Zeitraum-Filter
            HStack(spacing: 4) {
                ForEach(Zeitraum.allCases) { z in
                    Button(z.rawValue) { zeitraum = z }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(zeitraum == z ? .accentColor : .secondary)
                }
                Spacer()
                Text("\(historie.count)")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))

            Divider()

            if historie.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32)).foregroundColor(.secondary.opacity(0.4))
                    Text("Keine Bewegungen in diesem Zeitraum.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(historie) { b in
                            HistorieZeileKompakt(bewegung: b, ausgewaehlt: auswahl?.id == b.id)
                                .background(auswahl?.id == b.id
                                    ? Color.accentColor.opacity(0.15)
                                    : Color(.controlBackgroundColor))
                                .contentShape(Rectangle())
                                .onTapGesture { auswahl = b }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.controlBackgroundColor))
            }
        }
        .navigationTitle("Historie")
    }
}

// MARK: - Zeile

private struct HistorieZeileKompakt: View {
    @EnvironmentObject var vm: AppViewModel
    let bewegung: Bewegung
    let ausgewaehlt: Bool

    private var warBei: String {
        if let rkId = bewegung.stellvertretungRKId { return vm.rkName(id: rkId) }
        return bewegung.aufenthaltsText
    }

    private var dauerText: String {
        guard let zurueck = bewegung.datumRueckgabe else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: bewegung.datumAbgang, to: zurueck).day ?? 0
        return tage == 1 ? "1 Tag" : "\(tage) Tage"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                // Zeile 1: Kundenname + Rückgabedatum
                HStack {
                    Text(vm.kundeName(id: bewegung.kundenId))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    if let zurueck = bewegung.datumRueckgabe {
                        Text(zurueck.anzeigeText)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                // Zeile 2: Nr. + Grund
                HStack(spacing: 6) {
                    if let k = vm.kunde(id: bewegung.kundenId) {
                        Text("Nr. \(k.kundennummer)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Text("·").font(.caption2).foregroundColor(.secondary)
                    Text(bewegung.grund.rawValue)
                        .font(.caption2).foregroundColor(.secondary)
                }
                .lineLimit(1)

                // Zeile 3: War bei + Dauer
                HStack(spacing: 6) {
                    Text("War bei: \(warBei)")
                        .font(.caption)
                        .foregroundColor(bewegung.stellvertretungRKId != nil ? .orange : .secondary)
                    Text("·").font(.caption2).foregroundColor(.secondary)
                    Text(dauerText)
                        .font(.caption).foregroundColor(.secondary)
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
