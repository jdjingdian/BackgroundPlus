import SwiftUI

struct BTMEntryListContainerView: View {
    @ObservedObject var viewModel: BTMViewModel

    var body: some View {
        Group {
            if viewModel.entryLoadingState == .loading {
                ProgressView(localized("btm.list.state.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.shouldShowInstallPrompt {
                BTMMissingHelperView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        if viewModel.parseIncomplete {
                            Text("btm.error.parse_incomplete")
                                .foregroundStyle(.orange)
                        }

                        if let errorKey = viewModel.errorKey {
                            Text(localized(errorKey))
                                .foregroundStyle(.red)
                        }

                        ForEach(viewModel.filteredEntries) { entry in
                            BTMEntryListRowView(
                                entry: entry,
                                isEnabled: viewModel.enabledState(for: entry),
                                canOpenCustomDetail: viewModel.canOpenCustomDetail(for: entry),
                                onToggle: { isOn in
                                    viewModel.setEnabledState(isOn, for: entry)
                                },
                                onOpenCustomDetail: {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        viewModel.openCustomDetail(for: entry)
                                    }
                                }
                            )
                            .id(entry.id)
                        }
                    }
                    .onAppear {
                        guard let selectedEntryID = viewModel.selectedEntryID else { return }
                        proxy.scrollTo(selectedEntryID, anchor: .center)
                    }
                    .onChange(of: viewModel.selectedEntryID) { _, selectedEntryID in
                        guard let selectedEntryID else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedEntryID, anchor: .center)
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: Text("btm.list.search_placeholder"))
        .alert(
            Text("btm.custom_detail.unavailable.title"),
            isPresented: Binding(
                get: { viewModel.customDetailUnavailableMessageKey != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.customDetailUnavailableMessageKey = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.customDetailUnavailableMessageKey = nil
                }
            },
            message: {
                Text(localized(viewModel.customDetailUnavailableMessageKey ?? "btm.custom_detail.unavailable"))
            }
        )
    }
}
