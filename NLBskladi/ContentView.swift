import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: InvestmentViewModel

    @MainActor
    init(viewModel: InvestmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: InvestmentViewModel())
    }

    var body: some View {
        DashboardView(viewModel: viewModel)
    }
}

#Preview("Uspešen prikaz") {
    ContentView(viewModel: .previewLoaded)
}

#Preview("Prazen portfelj") {
    ContentView(viewModel: .previewEmpty)
}
