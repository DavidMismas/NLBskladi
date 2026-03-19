import Foundation

enum FundServiceError: LocalizedError, Equatable, Sendable {
    case noConnection
    case parsingFailed
    case websiteChanged
    case historicalDataUnavailable
    case missingCalculationData
    case invalidUserInput

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "Ni internetne povezave."
        case .parsingFailed:
            return "Podatkov trenutno ni bilo mogoče razbrati."
        case .websiteChanged:
            return "Spletna stran NLB Skladi se je verjetno spremenila."
        case .historicalDataUnavailable:
            return "Za izbrani datum ni bilo mogoče pridobiti zgodovinske vrednosti enote."
        case .missingCalculationData:
            return "Dodajte vsaj eno vplačilo."
        case .invalidUserInput:
            return "Vneseni podatki niso veljavni."
        }
    }

    var refreshMessage: String {
        switch self {
        case .noConnection:
            return "Ni povezave. Prikazani so zadnji shranjeni podatki, če so na voljo."
        case .parsingFailed, .websiteChanged:
            return "Podatkov trenutno ni bilo mogoče osvežiti."
        case .historicalDataUnavailable, .missingCalculationData, .invalidUserInput:
            return errorDescription ?? "Prišlo je do napake."
        }
    }
}
