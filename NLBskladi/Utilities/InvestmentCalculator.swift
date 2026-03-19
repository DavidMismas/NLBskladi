import Foundation

enum InvestmentCalculator {
    static func calculate(
        investment: UserInvestment,
        purchaseNAVs: [Date: Decimal],
        snapshot: FundSnapshot?
    ) throws -> InvestmentResult {
        guard let snapshot else {
            throw FundServiceError.missingCalculationData
        }

        guard !investment.contributions.isEmpty else {
            throw FundServiceError.missingCalculationData
        }

        let calendar = Calendar(identifier: .gregorian)
        var totalUnits = Decimal.zero

        for contribution in investment.contributions {
            guard contribution.investedAmount > .zero else {
                throw FundServiceError.invalidUserInput
            }

            let normalizedDate = calendar.startOfDay(for: contribution.purchaseDate)
            guard let purchaseNAV = purchaseNAVs[normalizedDate], purchaseNAV > .zero else {
                throw FundServiceError.historicalDataUnavailable
            }

            totalUnits += contribution.investedAmount / purchaseNAV
        }

        let totalInvestedAmount = investment.totalInvestedAmount
        let currentValue = totalUnits * snapshot.navValue
        let profitLoss = currentValue - totalInvestedAmount
        let profitLossPercent = totalInvestedAmount == .zero ? nil : (profitLoss / totalInvestedAmount) * 100
        let description = "Izračun temelji na \(investment.contributions.count) vplačilih in javni zgodovini VEP sklada."

        return InvestmentResult(
            currentValue: currentValue,
            profitLoss: profitLoss,
            profitLossPercent: profitLossPercent,
            calculationModeDescription: description
        )
    }
}
