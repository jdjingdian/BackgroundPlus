import AppKit
import SwiftUI

struct BackgroundItemDetailViewModel {
    let entry: BTMEntry

    init(entry: BTMEntry) {
        self.entry = entry
    }

    var displayName: String {
        entry.name.isEmpty ? entry.identifier : entry.name
    }
}

struct BackgroundItemDetailView: View {
    @ObservedObject var viewModel: BTMViewModel
    private let detailViewModel: BackgroundItemDetailViewModel

    let requestDelete: (BTMEntry) -> Void

    init(
        viewModel: BTMViewModel,
        entry: BTMEntry,
        requestDelete: @escaping (BTMEntry) -> Void
    ) {
        self.viewModel = viewModel
        self.detailViewModel = BackgroundItemDetailViewModel(entry: entry)
        self.requestDelete = requestDelete
    }

    var body: some View {
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
                    BTMDetailRowView(titleKey: "btm.detail.field.identifier", value: detailViewModel.entry.identifier)
                    BTMDetailRowView(titleKey: "btm.detail.field.bundle_id", value: detailViewModel.entry.bundleID)
                    BTMDetailRowView(titleKey: "btm.detail.field.path", value: detailViewModel.entry.url)
                    BTMDetailRowView(titleKey: "btm.detail.field.generation", value: String(detailViewModel.entry.generation))
                    BTMDetailRowView(titleKey: "btm.detail.field.type", value: detailViewModel.entry.type.rawValue)
                }

                Picker("btm.delete.mode", selection: $viewModel.mode) {
                    Text("btm.delete.mode.safe").tag(DeleteMode.safe)
                    Text("btm.delete.mode.advanced").tag(DeleteMode.advanced)
                }

                Button(role: .destructive) {
                    requestDelete(detailViewModel.entry)
                } label: {
                    Text("btm.confirm.button.delete")
                }
                .accessibilityIdentifier("btm.detail.delete_button")

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
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
