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

            if let unitsOwned = contribution.unitsOwned {
                guard unitsOwned > .zero else {
                    throw FundServiceError.invalidUserInput
                }

                totalUnits += unitsOwned
                continue
            }

            let netAmount = contribution.netInvestedAmount
            guard netAmount > .zero else {
                throw FundServiceError.invalidUserInput
            }

            if let purchaseNAV = contribution.purchaseNAV {
                guard purchaseNAV > .zero else {
                    throw FundServiceError.invalidUserInput
                }

                totalUnits += netAmount / purchaseNAV
                continue
            }

            let normalizedDate = calendar.startOfDay(for: contribution.purchaseDate)
            guard let purchaseNAV = purchaseNAVs[normalizedDate], purchaseNAV > .zero else {
                throw FundServiceError.historicalDataUnavailable
            }

            totalUnits += netAmount / purchaseNAV
        }

        let totalInvestedAmount = investment.totalInvestedAmount
        let currentValue = totalUnits * snapshot.navValue
        let profitLoss = currentValue - totalInvestedAmount
        let profitLossPercent = totalInvestedAmount == .zero ? nil : (profitLoss / totalInvestedAmount) * 100
        let exactContributions = investment.contributions.filter { $0.unitsOwned != nil }.count
        let description: String
        if exactContributions == investment.contributions.count {
            description = "Izračun temelji na dejanskem številu enot za vseh \(investment.contributions.count) vplačil."
        } else {
            description = "Izračun temelji na \(exactContributions) natančnih vplačilih in po potrebi na neto znesku ter VEP ob nakupu oziroma javni zgodovini VEP."
        }

        return InvestmentResult(
            currentValue: currentValue,
            profitLoss: profitLoss,
            profitLossPercent: profitLossPercent,
            calculationModeDescription: description
        )
    }
}
