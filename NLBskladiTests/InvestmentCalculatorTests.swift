import XCTest
@testable import NLBskladi

final class InvestmentCalculatorTests: XCTestCase {
    func testCalculationWithExactUnitsReturnsExpectedCurrentValue() throws {
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
            InvestmentContribution(
                investedAmount: Decimal(string: "100")!,
                transactionCost: Decimal(string: "1.96")!,
                purchaseNAV: Decimal(string: "36.9419")!,
                unitsOwned: Decimal(string: "2.653897")!,
                purchaseDate: firstDate
            ),
            InvestmentContribution(
                investedAmount: Decimal(string: "580")!,
                transactionCost: Decimal(string: "11.24")!,
                purchaseNAV: Decimal(string: "29.7641")!,
                unitsOwned: Decimal(string: "19.032214")!,
                purchaseDate: secondDate
            )
        ])

        let result = try InvestmentCalculator.calculate(
            investment: investment,
            purchaseNAVs: [:],
            snapshot: snapshot
        )

        XCTAssertEqual(result.currentValue, Decimal(string: "780.699996"))
        XCTAssertEqual(result.profitLoss, Decimal(string: "100.699996"))
        XCTAssertEqual(result.profitLossPercent, Decimal(string: "14.8088229411764705882352941176470588235"))
    }
}
