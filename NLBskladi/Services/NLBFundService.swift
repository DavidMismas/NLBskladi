import Foundation

actor NLBFundService: FundDataService {
    private let pageURL: URL
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage

    init(
        pageURL: URL = URL(string: "https://www.nlbskladi.si/nalozbene-moznosti/vzajemni-skladi/visoka-tehnologija-delniski")!,
        session: URLSession? = nil
    ) {
        self.pageURL = pageURL

        if let session {
            self.session = session
            self.cookieStorage = .shared
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.httpShouldSetCookies = true
            configuration.httpCookieAcceptPolicy = .always
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
            self.cookieStorage = configuration.httpCookieStorage ?? .shared
        }
    }

    func fetchLatestSnapshot() async throws -> FundSnapshot {
        let fetchedAt = Date()
        let html = try await loadHTMLPage()
        let metadata = try NLBHTMLParser.parseMetadata(from: html, pageURL: pageURL)
        let fallbackSnapshot = NLBHTMLParser.parseFallbackSnapshot(
            from: html,
            sourceURL: pageURL,
            fallbackName: metadata.fundName,
            fetchedAt: fetchedAt
        )

        var latestArchiveEntry: FundArchiveEntry?
        var lastError: FundServiceError?

        do {
            let archiveEntries = try await loadArchiveEntries(using: metadata)
            latestArchiveEntry = archiveEntries.last
        } catch let error as FundServiceError {
            lastError = error
        } catch {
            lastError = .parsingFailed
        }

        do {
            let currentFund = try await loadCurrentFund(using: metadata)
            let navValue = try DecimalParser.parseRequiredDecimal(from: currentFund.nav)
            let navDate = latestArchiveEntry.flatMap { AppFormatters.apiDateFormatter.date(from: $0.date) } ?? fallbackSnapshot?.navDate

            return FundSnapshot(
                fundName: currentFund.name ?? metadata.fundName,
                navValue: navValue,
                navDate: navDate,
                sourceURL: pageURL,
                fetchedAt: fetchedAt
            )
        } catch let error as FundServiceError {
            lastError = lastError ?? error
        } catch {
            lastError = lastError ?? .parsingFailed
        }

        if let latestArchiveEntry {
            return try makeSnapshot(from: latestArchiveEntry, metadata: metadata, fetchedAt: fetchedAt)
        }

        if let fallbackSnapshot {
            return fallbackSnapshot
        }

        throw lastError ?? .parsingFailed
    }

    func fetchPurchaseNAVs(for dates: [Date]) async throws -> [Date: Decimal] {
        let calendar = Calendar(identifier: .gregorian)
        let normalizedDates = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
        guard let earliestDate = normalizedDates.first, let latestDate = normalizedDates.last else {
            return [:]
        }

        let html = try await loadHTMLPage()
        let metadata = try NLBHTMLParser.parseMetadata(from: html, pageURL: pageURL)
        let dateMin = calendar.date(byAdding: .day, value: -30, to: earliestDate) ?? earliestDate
        let archiveEntries = try await loadArchiveEntries(
            using: metadata,
            dateMin: dateMin,
            dateMax: latestDate
        )

        let historicalNAVs = try archiveEntries.compactMap { entry -> (Date, Decimal)? in
            guard
                let entryDate = AppFormatters.apiDateFormatter.date(from: entry.date),
                let fund = entry.funds.first
            else {
                return nil
            }

            return (entryDate, try DecimalParser.parseRequiredDecimal(from: fund.nav))
        }

        guard !historicalNAVs.isEmpty else {
            throw FundServiceError.historicalDataUnavailable
        }

        var result: [Date: Decimal] = [:]

        for normalizedDate in normalizedDates {
            guard let matchedNAV = historicalNAVs.last(where: { $0.0 <= normalizedDate })?.1 else {
                throw FundServiceError.historicalDataUnavailable
            }

            result[normalizedDate] = matchedNAV
        }

        return result
    }

    private func loadHTMLPage() async throws -> String {
        let request = makeRequest(url: pageURL)

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            throw FundServiceError.websiteChanged
        }

        if let responseURL = httpResponse.url {
            persistCookies(from: httpResponse, url: responseURL)
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw FundServiceError.parsingFailed
        }

        return html
    }

    private func loadArchiveEntries(
        using metadata: NLBPageMetadata,
        dateMin: Date,
        dateMax: Date
    ) async throws -> [FundArchiveEntry] {
        var components = URLComponents(url: metadata.archiveEndpointURL(relativeTo: pageURL), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "dateMin", value: AppFormatters.apiDateString(from: dateMin)),
            URLQueryItem(name: "dateMax", value: AppFormatters.apiDateString(from: dateMax))
        ]

        guard let url = components?.url else {
            throw FundServiceError.websiteChanged
        }

        let request = makeRequest(
            url: url,
            referer: pageURL.absoluteString,
            accept: "application/json, text/plain, */*",
            requestedWith: "XMLHttpRequest"
        )

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FundServiceError.parsingFailed
        }

        if httpResponse.statusCode == 403 {
            throw FundServiceError.websiteChanged
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw FundServiceError.parsingFailed
        }

        let decoder = JSONDecoder()
        let entries = try decoder.decode([FundArchiveEntry].self, from: data)
        return entries.sorted { $0.date < $1.date }
    }

    private func loadArchiveEntries(using metadata: NLBPageMetadata) async throws -> [FundArchiveEntry] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let dateMin = calendar.date(byAdding: .day, value: -45, to: today) ?? today
        return try await loadArchiveEntries(using: metadata, dateMin: dateMin, dateMax: today)
    }

    private func loadCurrentFund(using metadata: NLBPageMetadata) async throws -> CurrentFundPayload {
        guard let currentEndpointURL = metadata.currentEndpointURL(relativeTo: pageURL) else {
            throw FundServiceError.websiteChanged
        }

        var components = URLComponents(url: currentEndpointURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: metadata.fundID),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]

        guard let url = components?.url else {
            throw FundServiceError.websiteChanged
        }

        let request = makeRequest(
            url: url,
            referer: pageURL.absoluteString,
            accept: "application/json, text/plain, */*",
            requestedWith: "XMLHttpRequest"
        )

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FundServiceError.parsingFailed
        }

        if httpResponse.statusCode == 403 {
            throw FundServiceError.websiteChanged
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw FundServiceError.parsingFailed
        }

        return try JSONDecoder().decode(CurrentFundPayload.self, from: data)
    }

    private func makeSnapshot(
        from entry: FundArchiveEntry,
        metadata: NLBPageMetadata,
        fetchedAt: Date
    ) throws -> FundSnapshot {
        guard let fund = entry.funds.first else {
            throw FundServiceError.parsingFailed
        }

        guard let navDate = AppFormatters.apiDateFormatter.date(from: entry.date) else {
            throw FundServiceError.parsingFailed
        }

        return FundSnapshot(
            fundName: fund.name ?? fund.shortName ?? metadata.fundName,
            navValue: try DecimalParser.parseRequiredDecimal(from: fund.nav),
            navDate: navDate,
            sourceURL: pageURL,
            fetchedAt: fetchedAt
        )
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .cannotConnectToHost, .timedOut, .networkConnectionLost].contains(urlError.code) {
                throw FundServiceError.noConnection
            }

            throw FundServiceError.parsingFailed
        }
    }

    private var browserUserAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }

    private func makeRequest(
        url: URL,
        referer: String? = nil,
        accept: String = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        requestedWith: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("sl-SI,sl;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        if let requestedWith {
            request.setValue(requestedWith, forHTTPHeaderField: "X-Requested-With")
        }

        if let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
            HTTPCookie.requestHeaderFields(with: cookies).forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }

    private func persistCookies(from response: HTTPURLResponse, url: URL) {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            guard let key = item.key as? String, let value = item.value as? String else { return }
            partialResult[key] = value
        }

        HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url).forEach { cookie in
            cookieStorage.setCookie(cookie)
        }
    }
}

private struct CurrentFundPayload: Decodable {
    let name: String?
    let nav: String
}

private struct FundArchiveEntry: Decodable {
    let date: String
    let funds: [FundArchiveFund]
}

private struct FundArchiveFund: Decodable {
    let name: String?
    let nav: String
    let shortName: String?
}
