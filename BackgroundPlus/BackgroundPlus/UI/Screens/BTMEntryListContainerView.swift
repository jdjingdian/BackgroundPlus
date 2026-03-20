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
                        if let warningKey = viewModel.parseWarningBannerMessageKey {
                            StatusBanner(style: .warning, message: LocalizedStringKey(warningKey))
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
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

                        if viewModel.filteredEntries.isEmpty {
                            Text(viewModel.emptyStateKeyForSelectedSidebar)
                                .foregroundStyle(.secondary)
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

enum StatusBannerStyle {
    case warning
    case info

    var backgroundColor: Color {
        switch self {
        case .warning:
            return .orange.opacity(0.12)
        case .info:
            return .blue.opacity(0.12)
        }
    }

    var iconName: String {
        switch self {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
}

struct StatusBanner<ActionButton: View>: View {
    let style: StatusBannerStyle
    let message: LocalizedStringKey
    @ViewBuilder let actionButton: () -> ActionButton

    init(
        style: StatusBannerStyle,
        message: LocalizedStringKey,
        @ViewBuilder actionButton: @escaping () -> ActionButton = { EmptyView() }
    ) {
        self.style = style
        self.message = message
        self.actionButton = actionButton
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .foregroundStyle(style.iconColor)
                Text(message)
                    .font(.callout)
                Spacer(minLength: 8)
                actionButton()
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.backgroundColor)
            Divider()
        }
    }
}
