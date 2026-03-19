import Foundation

struct NLBPageMetadata: Sendable {
    let fundName: String
    let fundID: String
    let currentServicePath: String?
    let archiveServicePath: String

    func currentEndpointURL(relativeTo baseURL: URL) -> URL? {
        guard let currentServicePath else { return nil }
        return absoluteURL(for: currentServicePath + ".funds.json", relativeTo: baseURL)
    }

    func archiveEndpointURL(relativeTo baseURL: URL) -> URL {
        absoluteURL(for: archiveServicePath + ".fundsarchive.\(fundID).json", relativeTo: baseURL)!
    }

    private func absoluteURL(for path: String, relativeTo baseURL: URL) -> URL? {
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        components.path = path.hasPrefix("/") ? path : "/" + path
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

enum NLBHTMLParser {
    static func parseMetadata(from html: String, pageURL: URL) throws -> NLBPageMetadata {
        let fundName = firstMatch(in: html, patterns: [
            #"<title>\s*([^<]+?)\s*\|\s*NLB Skladi\s*</title>"#,
            #"<h1[^>]*>\s*<p>([^<]+)</p>"#,
            #"<h1[^>]*>\s*([^<]+?)\s*</h1>"#
        ])?.decodedHTML() ?? "NLB Skladi - Visoka tehnologija delniški"

        let keyvisualAttributes = try extractAttributes(
            fromFirstTagMatching: #"<div[^>]*class="[^"]*nlb-product-keyvisual__bg[^"]*"[^>]*>"#,
            html: html
        )

        let comparatorAttributes = try extractAttributes(
            fromFirstTagMatching: #"<div[^>]*class="[^"]*js-unit-value-comparator[^"]*"[^>]*>"#,
            html: html
        )

        let fundID = keyvisualAttributes["data-fund-id"] ?? comparatorAttributes["data-fund-id"]
        let currentServicePath = keyvisualAttributes["data-service-path"]
        let archiveServicePath = comparatorAttributes["data-service-path"]

        guard let fundID, let archiveServicePath else {
            throw FundServiceError.websiteChanged
        }

        return NLBPageMetadata(
            fundName: fundName,
            fundID: fundID,
            currentServicePath: currentServicePath,
            archiveServicePath: archiveServicePath
        )
    }

    static func parseFallbackSnapshot(
        from html: String,
        sourceURL: URL,
        fallbackName: String,
        fetchedAt: Date
    ) -> FundSnapshot? {
        let name = firstMatch(in: html, patterns: [
            #"<title>\s*([^<]+?)\s*\|\s*NLB Skladi\s*</title>"#,
            #""name"\s*:\s*"([^"]+)""#
        ])?.decodedHTML() ?? fallbackName

        let navString = firstMatch(in: html, patterns: [
            #""nav"\s*:\s*"([0-9]+,[0-9]{2,4})""#,
            #"VEP na dan:\s*([0-9]+,[0-9]{2,4})"#,
            #"Vrednost enote premoženja[^0-9]*([0-9]+,[0-9]{2,4})"#
        ])

        guard let navString, let navValue = DecimalParser.parse(navString) else {
            return nil
        }

        let navDate = firstDate(in: html, patterns: [
            #""date"\s*:\s*"(\d{4}-\d{2}-\d{2})""#,
            #""vepDate"\s*:\s*"(\d{4}-\d{2}-\d{2})""#,
            #"(\d{2}\.\d{2}\.\d{4})"#
        ])

        return FundSnapshot(
            fundName: name,
            navValue: navValue,
            navDate: navDate,
            sourceURL: sourceURL,
            fetchedAt: fetchedAt
        )
    }

    private static func extractAttributes(fromFirstTagMatching pattern: String, html: String) throws -> [String: String] {
        guard let tag = firstMatch(in: html, patterns: [pattern]) else {
            throw FundServiceError.websiteChanged
        }

        var attributes: [String: String] = [:]
        let regex = try! NSRegularExpression(pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)="([^"]*)""#, options: [])
        let nsTag = tag as NSString

        for match in regex.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) where match.numberOfRanges == 3 {
            let key = nsTag.substring(with: match.range(at: 1))
            let value = nsTag.substring(with: match.range(at: 2))
            attributes[key] = value.decodedHTML()
        }

        return attributes
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        let nsText = text as NSString

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }

            let range = NSRange(location: 0, length: nsText.length)
            if let match = regex.firstMatch(in: text, range: range) {
                let captureIndex = match.numberOfRanges > 1 ? 1 : 0
                return nsText.substring(with: match.range(at: captureIndex))
            }
        }

        return nil
    }

    private static func firstDate(in text: String, patterns: [String]) -> Date? {
        guard let raw = firstMatch(in: text, patterns: patterns) else {
            return nil
        }

        if let apiDate = AppFormatters.apiDateFormatter.date(from: raw) {
            return apiDate
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sl_SI")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: raw)
    }
}

private extension String {
    func decodedHTML() -> String {
        self
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#43;", with: "+")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
