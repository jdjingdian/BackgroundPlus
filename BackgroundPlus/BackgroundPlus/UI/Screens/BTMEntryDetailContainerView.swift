import SwiftUI

struct BTMEntryDetailContainerView: View {
    @ObservedObject var viewModel: BTMViewModel
    let requestDelete: (BTMEntry) -> Void

    var body: some View {
        Group {
            if viewModel.entryLoadingState == .loading {
                ProgressView(localized("btm.list.state.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.shouldShowInstallPrompt {
                BTMMissingHelperView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry = viewModel.selectedEntry {
                detailContent(entry: entry)
            } else {
                Text("btm.list.empty")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detailContent(entry: BTMEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.parseIncomplete {
                    Text("btm.error.parse_incomplete")
                        .foregroundStyle(.orange)
                }

                if let errorKey = viewModel.errorKey {
                    Text(localized(errorKey))
                        .foregroundStyle(.red)
                }

                Group {
                    BTMDetailRowView(titleKey: "btm.detail.field.identifier", value: entry.identifier)
                    BTMDetailRowView(titleKey: "btm.detail.field.bundle_id", value: entry.bundleID)
                    BTMDetailRowView(titleKey: "btm.detail.field.path", value: entry.url)
                    BTMDetailRowView(titleKey: "btm.detail.field.generation", value: String(entry.generation))
                    BTMDetailRowView(titleKey: "btm.detail.field.type", value: entry.type.rawValue)
                }

                Picker("btm.delete.mode", selection: $viewModel.mode) {
                    Text("btm.delete.mode.safe").tag(DeleteMode.safe)
                    Text("btm.delete.mode.advanced").tag(DeleteMode.advanced)
                }

                Button(role: .destructive) {
                    requestDelete(entry)
                } label: {
                    Text("btm.confirm.button.delete")
                }

                if let result = viewModel.result {
                    Divider()
                    Text(localizedStatusTitle(result.executionStatus))
                        .font(.headline)
                    Text(localized(result.postCheckSummary))
                        .foregroundStyle(.secondary)
                    if !result.backupPath.isEmpty {
                        Text(String(format: localized("btm.result.backup.path"), result.backupPath))
                            .font(.footnote)
                    }
                }

                if !viewModel.history.isEmpty {
                    Divider()
                    Text("btm.history.title")
                        .font(.headline)
                    ForEach(viewModel.history.prefix(5)) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.targetIdentifier)
                                .font(.subheadline)
                            if !record.backupPath.isEmpty {
                                Text(String(format: localized("btm.result.backup.path"), record.backupPath))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Text("btm.detail.section.basic"))
    }

    private func localizedStatusTitle(_ status: ExecutionStatus) -> String {
        switch status {
        case .success:
            localized("btm.result.success.title")
        case .failed:
            localized("btm.result.fail.title")
        case .rolledBack:
            localized("btm.result.rollback.title")
        }
    }
}
