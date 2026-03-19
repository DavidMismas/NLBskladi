import Foundation

struct FundSnapshot: Codable, Equatable, Sendable {
    let fundName: String
    let navValue: Decimal
    let navDate: Date?
    let sourceURL: URL
    let fetchedAt: Date
}
