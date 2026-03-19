import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: InvestmentViewModel
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case contributionAmount
        case transactionCost
        case purchaseNAV
        case units
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    fundCard
                    resultCard
                    investmentCard
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Moj sklad")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Končaj") {
                        focusedField = nil
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var fundCard: some View {
        SectionCard(title: "Sklad") {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.fundSnapshot?.fundName ?? "NLB Skladi - Visoka tehnologija delniški")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(alignment: .top, spacing: 16) {
                    valueStack(
                        title: "Trenutna vrednost enote",
                        value: viewModel.fundSnapshot.map { AppFormatters.currencyString(from: $0.navValue) } ?? "Ni podatka"
                    )

                    Spacer(minLength: 12)

                    valueStack(
                        title: "Datum zadnje vrednosti",
                        value: viewModel.currentSnapshotDateText
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(viewModel.refreshState.title)
                    } icon: {
                        if viewModel.refreshState == .loading {
                            ProgressView()
                        } else {
                            Image(systemName: refreshIconName)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(refreshColor)

                    Text(viewModel.refreshState.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Zadnja uspešna osvežitev: \(viewModel.lastSuccessfulRefreshText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Osveži podatke")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.09, green: 0.21, blue: 0.53))
            }
        }
    }

    private var investmentCard: some View {
        SectionCard(title: "Moja vplačila") {
            VStack(alignment: .leading, spacing: 16) {
                textField(
                    title: "Znesek vplačila",
                    placeholder: "Na primer 300,00",
                    field: .contributionAmount,
                    text: Binding(
                        get: { viewModel.newContributionAmountText },
                        set: viewModel.updateNewContributionAmount
                    )
                )

                textField(
                    title: "Stroški transakcije",
                    placeholder: "Na primer 1,96",
                    field: .transactionCost,
                    text: Binding(
                        get: { viewModel.newContributionTransactionCostText },
                        set: viewModel.updateNewContributionTransactionCost
                    )
                )

                textField(
                    title: "Vrednost enote ob nakupu",
                    placeholder: "Na primer 36,9419",
                    field: .purchaseNAV,
                    text: Binding(
                        get: { viewModel.newContributionPurchaseNAVText },
                        set: viewModel.updateNewContributionPurchaseNAV
                    )
                )

                textField(
                    title: "Št. enot premoženja",
                    placeholder: "Na primer 2,653897",
                    field: .units,
                    text: Binding(
                        get: { viewModel.newContributionUnitsText },
                        set: viewModel.updateNewContributionUnits
                    )
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Datum vplačila")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Datum vplačila",
                        selection: Binding(
                            get: { viewModel.newContributionDate },
                            set: viewModel.updateNewContributionDate
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.addContribution()
                    focusedField = nil
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Dodaj vplačilo")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Divider()

                valueRow("Skupaj vloženo", viewModel.totalInvestedAmountText)
                valueRow("Število vplačil", "\(viewModel.contributions.count)")

                Text("Za najbolj natančen izračun vnesite tudi strošek transakcije in št. enot premoženja. Če št. enot ne vnesete, app uporabi VEP ob nakupu oziroma javno zgodovino sklada.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.contributions.isEmpty {
                    EmptyView()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.contributions) { contribution in
                            contributionRow(contribution)
                        }
                    }
                }
            }
        }
    }

    private var resultCard: some View {
        SectionCard(title: "Trenutna vrednost") {
            VStack(alignment: .leading, spacing: 14) {
                if let result = viewModel.calculationResult {
                    VStack(alignment: .leading, spacing: 12) {
                        valueRow("Skupaj vplačano", viewModel.totalInvestedAmountText)
                        valueRow("Ocenjena vrednost", result.currentValue.map(AppFormatters.currencyString(from:)) ?? "Ni podatka")
                        valueRow("Razlika v EUR", result.profitLoss.map(AppFormatters.signedCurrencyString(from:)) ?? "Ni podatka")
                        valueRow("Donos", result.profitLossPercent.map(AppFormatters.signedPercentString(from:)) ?? "Ni podatka")

                        Text(result.calculationModeDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(viewModel.calculationMessage ?? "Za izračun dodajte svoja vplačila.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func contributionRow(_ contribution: InvestmentContribution) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormatters.currencyString(from: contribution.investedAmount))
                    .font(.headline)
                Text(AppFormatters.dateString(from: contribution.purchaseDate))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let transactionCost = contribution.transactionCost {
                    Text("Strošek: \(AppFormatters.currencyString(from: transactionCost))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let purchaseNAV = contribution.purchaseNAV {
                    Text("VEP: \(DecimalParser.string(from: purchaseNAV))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let unitsOwned = contribution.unitsOwned {
                    Text("Enote: \(DecimalParser.string(from: unitsOwned))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Button(role: .destructive) {
                viewModel.removeContribution(id: contribution.id)
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func valueStack(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func textField(title: String, placeholder: String, field: InputField, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
    }

    private var refreshColor: Color {
        switch viewModel.refreshState {
        case .idle:
            return .secondary
        case .loading:
            return .orange
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    private var refreshIconName: String {
        switch viewModel.refreshState {
        case .idle:
            return "clock"
        case .loading:
            return "arrow.trianglehead.2.clockwise"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }
}
