import Foundation

struct InvestmentResult: Equatable, Sendable {
    let currentValue: Decimal?
    let profitLoss: Decimal?
    let profitLossPercent: Decimal?
    let calculationModeDescription: String
}
