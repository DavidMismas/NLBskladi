import Foundation

protocol InvestmentStorage {
    func loadInvestment() -> UserInvestment
    func saveInvestment(_ investment: UserInvestment)
    func loadSnapshot() -> FundSnapshot?
    func saveSnapshot(_ snapshot: FundSnapshot)
}

struct UserDefaultsInvestmentStorage: InvestmentStorage {
    private enum Keys {
        static let investment = "userInvestment"
        static let snapshot = "fundSnapshot"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadInvestment() -> UserInvestment {
        guard
            let data = defaults.data(forKey: Keys.investment),
            let investment = try? decoder.decode(UserInvestment.self, from: data)
        else {
            return .empty
        }

        return investment
    }

    func saveInvestment(_ investment: UserInvestment) {
        guard let data = try? encoder.encode(investment) else { return }
        defaults.set(data, forKey: Keys.investment)
    }

    func loadSnapshot() -> FundSnapshot? {
        guard
            let data = defaults.data(forKey: Keys.snapshot),
            let snapshot = try? decoder.decode(FundSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    func saveSnapshot(_ snapshot: FundSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.snapshot)
    }
}
