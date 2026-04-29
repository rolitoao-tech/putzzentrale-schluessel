import Foundation

extension DateFormatter {
    static let anzeige: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
}

extension Date {
    var anzeigeText: String { DateFormatter.anzeige.string(from: self) }

    var istHeute: Bool { Calendar.current.isDateInToday(self) }
    var istInVergangenheit: Bool { self < Calendar.current.startOfDay(for: Date()) }
}
