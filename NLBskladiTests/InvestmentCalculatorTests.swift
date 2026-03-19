import XCTest
@testable import NLBskladi

final class InvestmentCalculatorTests: XCTestCase {
    func testCalculationWithMultipleContributionsReturnsExpectedCurrentValue() throws {
        let snapshot = FundSnapshot(
            fundName: "NLB Skladi - Visoka tehnologija delniški",
            navValue: Decimal(string: "36.00")!,
            navDate: Date(timeIntervalSince1970: 0),
            sourceURL: URL(string: "https://www.nlbskladi.si/nalozbene-moznosti/vzajemni-skladi/visoka-tehnologija-delniski")!,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let firstDate = AppFormatters.apiDateFormatter.date(from: "2025-06-16")!
        let secondDate = AppFormatters.apiDateFormatter.date(from: "2025-07-16")!
        let investment = UserInvestment(contributions: [
            InvestmentContribution(investedAmount: Decimal(string: "1000")!, purchaseDate: firstDate),
            InvestmentContribution(investedAmount: Decimal(string: "300")!, purchaseDate: secondDate)
        ])

        let purchaseNAVs: [Date: Decimal] = [
            Calendar(identifier: .gregorian).startOfDay(for: firstDate): Decimal(string: "25")!,
            Calendar(identifier: .gregorian).startOfDay(for: secondDate): Decimal(string: "30")!
        ]

        let result = try InvestmentCalculator.calculate(
            investment: investment,
            purchaseNAVs: purchaseNAVs,
            snapshot: snapshot
        )

        XCTAssertEqual(result.currentValue, Decimal(string: "1800"))
        XCTAssertEqual(result.profitLoss, Decimal(string: "500"))
        XCTAssertEqual(result.profitLossPercent, Decimal(string: "38.461538461538461538461538461538461538"))
    }
}
