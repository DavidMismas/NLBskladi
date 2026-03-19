import Foundation

protocol FundDataService: Sendable {
    func fetchLatestSnapshot() async throws -> FundSnapshot
    func fetchPurchaseNAVs(for dates: [Date]) async throws -> [Date: Decimal]
}
