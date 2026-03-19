import Foundation

struct InvestmentContribution: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var investedAmount: Decimal
    var transactionCost: Decimal?
    var purchaseNAV: Decimal?
    var unitsOwned: Decimal?
    var purchaseDate: Date

    init(
        id: UUID = UUID(),
        investedAmount: Decimal,
        transactionCost: Decimal? = nil,
        purchaseNAV: Decimal? = nil,
        unitsOwned: Decimal? = nil,
        purchaseDate: Date
    ) {
        self.id = id
        self.investedAmount = investedAmount
        self.transactionCost = transactionCost
        self.purchaseNAV = purchaseNAV
        self.unitsOwned = unitsOwned
        self.purchaseDate = Calendar(identifier: .gregorian).startOfDay(for: purchaseDate)
    }

    var netInvestedAmount: Decimal {
        investedAmount - (transactionCost ?? .zero)
    }
}

struct UserInvestment: Codable, Equatable, Sendable {
    var contributions: [InvestmentContribution]

    init(contributions: [InvestmentContribution] = []) {
        self.contributions = contributions.sorted { $0.purchaseDate > $1.purchaseDate }
    }

    var totalInvestedAmount: Decimal {
        contributions.reduce(.zero) { $0 + $1.investedAmount }
    }

    static let empty = UserInvestment()

    private enum CodingKeys: String, CodingKey {
        case contributions
        case investedAmount
        case purchaseDate
        case transactionCost
        case purchaseNAV
        case unitsOwned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let contributions = try container.decodeIfPresent([InvestmentContribution].self, forKey: .contributions) {
            self.init(contributions: contributions)
            return
        }

        let legacyAmount = try container.decodeIfPresent(Decimal.self, forKey: .investedAmount) ?? .zero
        let legacyDate = try container.decodeIfPresent(Date.self, forKey: .purchaseDate)
        let legacyCost = try container.decodeIfPresent(Decimal.self, forKey: .transactionCost)
        let legacyPurchaseNAV = try container.decodeIfPresent(Decimal.self, forKey: .purchaseNAV)
        let legacyUnits = try container.decodeIfPresent(Decimal.self, forKey: .unitsOwned)

        if legacyAmount > .zero, let legacyDate {
            self.init(contributions: [
                InvestmentContribution(
                    investedAmount: legacyAmount,
                    transactionCost: legacyCost,
                    purchaseNAV: legacyPurchaseNAV,
                    unitsOwned: legacyUnits,
                    purchaseDate: legacyDate
                )
            ])
        } else {
            self.init()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contributions, forKey: .contributions)
    }
}
