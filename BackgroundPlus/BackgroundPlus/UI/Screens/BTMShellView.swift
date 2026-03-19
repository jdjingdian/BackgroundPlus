import SwiftUI

struct BTMShellView: View {
    @ObservedObject var viewModel: BTMViewModel
    private let toolbarBackSlotWidth: CGFloat = 28

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
        ZStack {
            BTMEntryListContainerView(viewModel: viewModel)
                .disabled(viewModel.customDetailEntry != nil)

            if let entry = viewModel.customDetailEntry {
                BackgroundItemDetailView(
                    viewModel: viewModel,
                    entry: entry,
                    requestDelete: { selectedEntry in
                        let planning = viewModel.planning(for: selectedEntry)
                        currentPlan = planning.0
                        currentRisk = planning.1
                        currentConfirmation = planning.2
                        showDeleteSheet = true
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
                .id(entry.id)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.customDetailEntryID)
        .navigationTitle(Text("btm.list.title"))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                navigationBackSlot
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.load()
                } label: {
                    Label("btm.list.refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    viewModel.openBackupFolder()
                } label: {
                    Label("btm.result.button.open_backup", systemImage: "folder")
                }

                SettingsLink {
                    Label("btm.settings.button", systemImage: "gearshape")
                }
            }
        }
    }

    @ViewBuilder
    private var navigationBackSlot: some View {
        if viewModel.customDetailEntry != nil {
            Button(action: closeCustomDetail) {
                Label("btm.custom_detail.back", systemImage: "chevron.left")
            }
            .accessibilityIdentifier("btm.toolbar.back")
            .frame(minWidth: toolbarBackSlotWidth, alignment: .leading)
        } else {
            Label("btm.custom_detail.back", systemImage: "chevron.left")
                .hidden()
                .accessibilityHidden(true)
                .frame(minWidth: toolbarBackSlotWidth, alignment: .leading)
        }
    }

    private func closeCustomDetail() {
        withAnimation(.easeOut(duration: 0.25)) {
            viewModel.closeCustomDetail()
        }
    }
}
