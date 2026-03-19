import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BTMViewModel()
    @State private var showDeleteSheet = false
    @State private var currentPlan: DeletePlan?
    @State private var currentRisk: RiskLevel = .low
    @State private var currentConfirmation: ConfirmationLevel = .single

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedEntryID) {
                ForEach(viewModel.filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name.isEmpty ? entry.identifier : entry.name)
                            .font(.headline)
                        Text(entry.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(entry.id)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("btm.list.search_placeholder"))
            .toolbar {
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
                }
            }
            .navigationTitle(Text("btm.list.title"))
            .accessibilityIdentifier("btm.list.title")
        } detail: {
            detailView
        }
        .task {
            viewModel.load()
        }
        .sheet(isPresented: $showDeleteSheet) {
            if let entry = viewModel.selectedEntry,
               let plan = currentPlan {
                DeleteConfirmView(
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

    @ViewBuilder
    private var detailView: some View {
        if let entry = viewModel.selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.parseIncomplete {
                        Text("btm.error.parse_incomplete")
                            .foregroundStyle(.orange)
                    }
                    Group {
                        detailRow("btm.detail.field.identifier", value: entry.identifier)
                        detailRow("btm.detail.field.bundle_id", value: entry.bundleID)
                        detailRow("btm.detail.field.path", value: entry.url)
                        detailRow("btm.detail.field.generation", value: String(entry.generation))
                        detailRow("btm.detail.field.type", value: entry.type.rawValue)
                    }

                    Picker("btm.delete.mode", selection: $viewModel.mode) {
                        Text("btm.delete.mode.safe").tag(DeleteMode.safe)
                        Text("btm.delete.mode.advanced").tag(DeleteMode.advanced)
                    }

                    Button(role: .destructive) {
                        let planning = viewModel.planning(for: entry)
                        currentPlan = planning.0
                        currentRisk = planning.1
                        currentConfirmation = planning.2
                        showDeleteSheet = true
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
        } else {
            Text("btm.list.empty")
                .foregroundStyle(.secondary)
        }
    }

    private func detailRow(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localized(key))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
        }
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

private struct DeleteConfirmView: View {
    let entry: BTMEntry
    let plan: DeletePlan
    let risk: RiskLevel
    let confirmation: ConfirmationLevel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var challenge = ""
    @State private var enableAt = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titleKey)
                .font(.title3.bold())
                .accessibilityIdentifier(titleKey)

            Text(String(format: localized("btm.confirm.dry_run.summary"), plan.dryRunSummary.totalPlanned, typeBreakdown))

            List(plan.plannedEntries) { item in
                HStack {
                    Text(item.identifier)
                    Spacer()
                    if item.required {
                        Text("btm.delete.required")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 120)

            if confirmation == .textChallenge {
                TextField(localized("btm.confirm.challenge.placeholder"), text: $challenge)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(localized("btm.confirm.button.cancel")) {
                    onCancel()
                }
                Spacer()
                Button(localized("btm.confirm.button.delete"), role: .destructive) {
                    onConfirm()
                }
                .disabled(!canConfirm)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 400)
        .onAppear {
            enableAt = Date().addingTimeInterval(3)
        }
    }

    private var canConfirm: Bool {
        if confirmation == .textChallenge {
            let suffix = entry.identifier.split(separator: ".").last.map(String.init) ?? entry.identifier
            return challenge == suffix && Date() >= enableAt
        }
        return true
    }

    private var titleKey: String {
        switch risk {
        case .low:
            "btm.confirm.title.low"
        case .medium:
            "btm.confirm.title.medium"
        case .high:
            "btm.confirm.title.high"
        }
    }

    private var typeBreakdown: String {
        let pairs = plan.dryRunSummary.byType.sorted { $0.key.rawValue < $1.key.rawValue }
        return pairs.map { "\($0.value) \($0.key.rawValue)" }.joined(separator: ", ")
    }
}

private func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}

#Preview {
    ContentView()
}
