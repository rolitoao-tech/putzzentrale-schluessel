import Foundation

extension DateFormatter {
    static let iso8601Date: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let anzeige: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
}

extension Date {
    var anzeigeText: String { DateFormatter.anzeige.string(from: self) }
    var sqlText: String { DateFormatter.iso8601Date.string(from: self) }

    var istHeute: Bool { Calendar.current.isDateInToday(self) }
    var istInVergangenheit: Bool { self < Calendar.current.startOfDay(for: Date()) }
}
