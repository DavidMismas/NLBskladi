import Foundation

enum DecimalParser {
    static func parse(_ string: String?) -> Decimal? {
        guard let string else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized: String
        if trimmed.contains(",") {
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = trimmed
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func parseRequiredDecimal(from string: String) throws -> Decimal {
        guard let decimal = parse(string) else {
            throw FundServiceError.parsingFailed
        }

        return decimal
    }

    static func string(from decimal: Decimal) -> String {
        AppFormatters.decimalFormatter.string(from: NSDecimalNumber(decimal: decimal)) ?? ""
    }

    static func sanitizedInput(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "0123456789,.")
        return String(raw.unicodeScalars.filter { allowed.contains($0) })
    }
}
