import Foundation

enum AppFormatters {
    static let locale = Locale(identifier: "sl_SI")

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let signedCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter
    }()

    static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d. M. yyyy"
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d. M. yyyy 'ob' HH:mm"
        return formatter
    }()

    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func currencyString(from value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "Ni podatka"
    }

    static func signedCurrencyString(from value: Decimal) -> String {
        signedCurrencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "Ni podatka"
    }

    static func signedPercentString(from value: Decimal) -> String {
        let absolute = decimalFormatter.string(from: NSDecimalNumber(decimal: abs(value))) ?? "0"
        let sign = value < .zero ? "-" : "+"
        return "\(sign)\(absolute) %"
    }

    static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func dateTimeString(from date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func apiDateString(from date: Date) -> String {
        apiDateFormatter.string(from: date)
    }
}
