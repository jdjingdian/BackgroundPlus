import SwiftUI

struct BTMShellView: View {
    @ObservedObject var viewModel: BTMViewModel

    @State private var showDeleteSheet = false
    @State private var currentPlan: DeletePlan?
    @State private var currentRisk: RiskLevel = .low
    @State private var currentConfirmation: ConfirmationLevel = .single

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .task {
            viewModel.load()
        }
        .sheet(isPresented: $showDeleteSheet) {
            if let entry = viewModel.selectedEntry,
               let plan = currentPlan {
                BTMDeleteConfirmSheet(
                    entry: entry,
                    plan: plan,
                    risk: currentRisk,
                    confirmation: currentConfirmation,
                    onConfirm: {
                        viewModel.executeDelete(entry: entry)
                        showDeleteSheet = false
                    },
                    onCancel: {
                        showDeleteSheet = false
                    }
                )
            }
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedSidebarItem) {
            Label("btm.sidebar.background_modules", systemImage: "switch.2")
                .tag(BTMSidebarItem.backgroundModules)
        }
        .navigationTitle(Text("btm.list.title"))
    }

    @ViewBuilder
    private var detailContent: some View {
        if let entry = viewModel.customDetailEntry {
            BackgroundItemDetailView(
                viewModel: viewModel,
                entry: entry,
                onBack: {
                    viewModel.closeCustomDetail()
                },
                requestDelete: { selectedEntry in
                    let planning = viewModel.planning(for: selectedEntry)
                    currentPlan = planning.0
                    currentRisk = planning.1
                    currentConfirmation = planning.2
                    showDeleteSheet = true
                }
            )
        } else {
            BTMEntryListContainerView(viewModel: viewModel)
        }
    }
}
