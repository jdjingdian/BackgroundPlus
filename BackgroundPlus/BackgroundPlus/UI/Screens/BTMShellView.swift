import SwiftUI

struct BTMShellView: View {
    @ObservedObject var viewModel: BTMViewModel

    @State private var showDeleteSheet = false
    @State private var showSettingsSheet = false
    @State private var currentPlan: DeletePlan?
    @State private var currentRisk: RiskLevel = .low
    @State private var currentConfirmation: ConfirmationLevel = .single

    var body: some View {
        NavigationSplitView {
            BTMEntryListContainerView(viewModel: viewModel) {
                showSettingsSheet = true
            }
        } detail: {
            BTMEntryDetailContainerView(
                viewModel: viewModel,
                openSettings: {
                    showSettingsSheet = true
                },
                requestDelete: { entry in
                    let planning = viewModel.planning(for: entry)
                    currentPlan = planning.0
                    currentRisk = planning.1
                    currentConfirmation = planning.2
                    showDeleteSheet = true
                }
            )
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
        .sheet(isPresented: $showSettingsSheet) {
            HelperSettingsContainerView(viewModel: viewModel)
        }
    }
}
