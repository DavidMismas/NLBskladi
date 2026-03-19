import Foundation

enum RefreshState: Equatable {
    case idle
    case loading
    case success
    case failure(FundServiceError)

    var title: String {
        switch self {
        case .idle:
            return "Pripravljeno"
        case .loading:
            return "Nalaganje"
        case .success:
            return "Uspeh"
        case .failure:
            return "Napaka"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Podatki še niso bili osveženi v tej seji."
        case .loading:
            return "Osvežujem podatke iz NLB Skladi."
        case .success:
            return "Podatki sklada so uspešno osveženi."
        case let .failure(error):
            return error.refreshMessage
        }
    }
}
