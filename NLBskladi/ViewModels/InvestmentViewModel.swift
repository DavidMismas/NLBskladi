import Combine
import Foundation

@MainActor
final class InvestmentViewModel: ObservableObject {
    @Published private(set) var fundSnapshot: FundSnapshot?
    @Published private(set) var refreshState: RefreshState = .idle
    @Published private(set) var calculationResult: InvestmentResult?
    @Published private(set) var calculationMessage: String?
    @Published private(set) var investment: UserInvestment

    @Published var newContributionAmountText: String
    @Published var newContributionTransactionCostText: String
    @Published var newContributionPurchaseNAVText: String
    @Published var newContributionUnitsText: String
    @Published var newContributionDate: Date

    private let service: FundDataService
    private let storage: InvestmentStorage
    private var calculationTask: Task<Void, Never>?

    init(
        service: FundDataService,
        storage: InvestmentStorage
    ) {
        self.service = service
        self.storage = storage

        let defaultDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
        investment = storage.loadInvestment()
        fundSnapshot = storage.loadSnapshot()
        newContributionAmountText = ""
        newContributionTransactionCostText = ""
        newContributionPurchaseNAVText = ""
        newContributionUnitsText = ""
        newContributionDate = defaultDate

        recalculate()
    }

    var hasCachedSnapshot: Bool {
        fundSnapshot != nil
    }

    var contributions: [InvestmentContribution] {
        investment.contributions
    }

    var totalInvestedAmountText: String {
        AppFormatters.currencyString(from: investment.totalInvestedAmount)
    }

    var lastSuccessfulRefreshText: String {
        guard let fetchedAt = fundSnapshot?.fetchedAt else {
            return "Še ni na voljo"
        }

        return AppFormatters.dateTimeString(from: fetchedAt)
    }

    var currentSnapshotDateText: String {
        guard let navDate = fundSnapshot?.navDate else {
            return "Ni podatka"
        }

        return AppFormatters.dateString(from: navDate)
    }

    func refresh() async {
        refreshState = .loading

        do {
            let snapshot = try await service.fetchLatestSnapshot()
            fundSnapshot = snapshot
            storage.saveSnapshot(snapshot)
            refreshState = .success
            recalculate()
        } catch let error as FundServiceError {
            refreshState = .failure(error)
            recalculate()
        } catch {
            refreshState = .failure(.parsingFailed)
            recalculate()
        }
    }

    func updateNewContributionAmount(_ newValue: String) {
        newContributionAmountText = DecimalParser.sanitizedInput(newValue)
    }

    func updateNewContributionTransactionCost(_ newValue: String) {
        newContributionTransactionCostText = DecimalParser.sanitizedInput(newValue)
    }

    func updateNewContributionPurchaseNAV(_ newValue: String) {
        newContributionPurchaseNAVText = DecimalParser.sanitizedInput(newValue)
    }

    func updateNewContributionUnits(_ newValue: String) {
        newContributionUnitsText = DecimalParser.sanitizedInput(newValue)
    }

    func updateNewContributionDate(_ newValue: Date) {
        newContributionDate = Calendar(identifier: .gregorian).startOfDay(for: newValue)
    }

    func addContribution() {
        guard let amount = DecimalParser.parse(newContributionAmountText), amount > .zero else {
            calculationMessage = FundServiceError.invalidUserInput.errorDescription
            return
        }

        let transactionCost = DecimalParser.parse(newContributionTransactionCostText)
        let purchaseNAV = DecimalParser.parse(newContributionPurchaseNAVText)
        let unitsOwned = DecimalParser.parse(newContributionUnitsText)

        if let transactionCost, transactionCost < .zero {
            calculationMessage = FundServiceError.invalidUserInput.errorDescription
            return
        }

        if let purchaseNAV, purchaseNAV <= .zero {
            calculationMessage = FundServiceError.invalidUserInput.errorDescription
            return
        }

        if let unitsOwned, unitsOwned <= .zero {
            calculationMessage = FundServiceError.invalidUserInput.errorDescription
            return
        }

        investment.contributions.append(
            InvestmentContribution(
                investedAmount: amount,
                transactionCost: transactionCost,
                purchaseNAV: purchaseNAV,
                unitsOwned: unitsOwned,
                purchaseDate: newContributionDate
            )
        )
        investment = UserInvestment(contributions: investment.contributions)
        newContributionAmountText = ""
        newContributionTransactionCostText = ""
        newContributionPurchaseNAVText = ""
        newContributionUnitsText = ""
        storage.saveInvestment(investment)
        recalculate()
    }

    func removeContribution(id: UUID) {
        investment.contributions.removeAll { $0.id == id }
        storage.saveInvestment(investment)
        recalculate()
    }

    private func recalculate() {
        calculationTask?.cancel()
        calculationResult = nil

        guard !investment.contributions.isEmpty else {
            calculationMessage = "Dodajte prvo vplačilo."
            return
        }

        guard let snapshot = fundSnapshot else {
            calculationMessage = "Podatki sklada še niso na voljo."
            return
        }

        let contributions = investment.contributions
        calculationMessage = "Preračunavam portfelj iz vseh vplačil."

        calculationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let datesRequiringHistory = contributions
                    .filter { $0.unitsOwned == nil && $0.purchaseNAV == nil }
                    .map(\.purchaseDate)
                let purchaseNAVs = try await service.fetchPurchaseNAVs(for: datesRequiringHistory)
                try Task.checkCancellation()

                let result = try InvestmentCalculator.calculate(
                    investment: UserInvestment(contributions: contributions),
                    purchaseNAVs: purchaseNAVs,
                    snapshot: snapshot
                )

                calculationResult = result
                calculationMessage = nil
            } catch is CancellationError {
                return
            } catch let error as FundServiceError {
                calculationMessage = error.errorDescription
            } catch {
                calculationMessage = FundServiceError.parsingFailed.errorDescription
            }
        }
    }
}

extension InvestmentViewModel {
    @MainActor
    convenience init() {
        self.init(service: NLBFundService(), storage: UserDefaultsInvestmentStorage())
    }

    static let previewLoaded: InvestmentViewModel = {
        let storage = PreviewInvestmentStorage(
            investment: UserInvestment(contributions: [
                InvestmentContribution(investedAmount: 2500, transactionCost: 50, purchaseNAV: Decimal(string: "28.40"), unitsOwned: Decimal(string: "86.2676056"), purchaseDate: AppFormatters.apiDateFormatter.date(from: "2025-06-16")!),
                InvestmentContribution(investedAmount: 300, transactionCost: Decimal(string: "4.50"), purchaseNAV: Decimal(string: "30.25"), unitsOwned: Decimal(string: "9.768595"), purchaseDate: AppFormatters.apiDateFormatter.date(from: "2025-07-16")!),
                InvestmentContribution(investedAmount: 300, transactionCost: Decimal(string: "4.50"), purchaseNAV: Decimal(string: "31.10"), unitsOwned: Decimal(string: "9.5016077"), purchaseDate: AppFormatters.apiDateFormatter.date(from: "2025-08-16")!)
            ]),
            snapshot: PreviewData.snapshot
        )

        let viewModel = InvestmentViewModel(
            service: PreviewFundService(snapshot: PreviewData.snapshot),
            storage: storage
        )
        viewModel.refreshState = .success
        return viewModel
    }()

    static let previewEmpty: InvestmentViewModel = {
        let storage = PreviewInvestmentStorage(
            investment: .empty,
            snapshot: PreviewData.snapshot
        )

        let viewModel = InvestmentViewModel(
            service: PreviewFundService(snapshot: PreviewData.snapshot),
            storage: storage
        )
        viewModel.refreshState = .idle
        return viewModel
    }()
}

private struct PreviewData {
    static let snapshot = FundSnapshot(
        fundName: "NLB Skladi - Visoka tehnologija delniški",
        navValue: Decimal(string: "35.9985")!,
        navDate: AppFormatters.apiDateFormatter.date(from: "2026-03-17"),
        sourceURL: URL(string: "https://www.nlbskladi.si/nalozbene-moznosti/vzajemni-skladi/visoka-tehnologija-delniski")!,
        fetchedAt: Date(timeIntervalSince1970: 1_773_901_987)
    )
}

private struct PreviewFundService: FundDataService {
    let snapshot: FundSnapshot

    func fetchLatestSnapshot() async throws -> FundSnapshot {
        snapshot
    }

    func fetchPurchaseNAVs(for dates: [Date]) async throws -> [Date: Decimal] {
        let calendar = Calendar(identifier: .gregorian)
        return Dictionary(uniqueKeysWithValues: dates.map {
            (calendar.startOfDay(for: $0), Decimal(string: "28.40")!)
        })
    }
}

private struct PreviewInvestmentStorage: InvestmentStorage {
    let investment: UserInvestment
    let snapshot: FundSnapshot?

    func loadInvestment() -> UserInvestment { investment }
    func saveInvestment(_ investment: UserInvestment) {}
    func loadSnapshot() -> FundSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: FundSnapshot) {}
}
