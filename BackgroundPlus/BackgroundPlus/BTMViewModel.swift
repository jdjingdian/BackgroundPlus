import AppKit
import Combine
import Foundation
import SwiftUI

final class BTMViewModel: ObservableObject {
    @Published var entries: [BTMEntry] = []
    @Published var parseIncomplete = false
    @Published var selectedEntryID: String?
    @Published var mode: DeleteMode = .safe
    @Published var result: OperationRecord?
    @Published var history: [OperationRecord] = []
    @Published var errorKey: String?
    @Published var searchText = ""

    private let manager: BTMManager

    init(manager: BTMManager? = nil) {
        self.manager = manager ?? BTMViewModel.defaultManager()
    }

    static func defaultManager() -> BTMManager {
        let useFixture = ProcessInfo.processInfo.arguments.contains("--ui-test-fixture")
        let source: BTMDataSource = useFixture ? FixtureDataSource() : SFLToolDataSource()
        return BTMManager(
            source: source,
            database: InMemoryDatabaseAdapter(seed: [
                "2.cn.magicdian.staticrouter",
                "16.cn.magicdian.staticrouter.service"
            ]),
            backupManager: BackupManager()
        )
    }

    var selectedEntry: BTMEntry? {
        guard let selectedEntryID else { return nil }
        return entries.first(where: { $0.id == selectedEntryID })
    }

    var filteredEntries: [BTMEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.identifier.localizedCaseInsensitiveContains(searchText)
                || $0.bundleID.localizedCaseInsensitiveContains(searchText)
                || $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    func load() {
        do {
            let result = try manager.loadEntries()
            entries = result.entries
            parseIncomplete = result.parseIncomplete
            if selectedEntryID == nil {
                selectedEntryID = entries.first?.id
            }
        } catch {
            errorKey = "btm.error.parse_incomplete"
        }
    }

    func planning(for entry: BTMEntry) -> (DeletePlan, RiskLevel, ConfirmationLevel) {
        manager.buildPlan(target: entry, entries: entries, mode: mode, parseIncomplete: parseIncomplete)
    }

    func executeDelete(entry: BTMEntry) {
        let (plan, risk, confirmation) = planning(for: entry)
        let dbFiles: [URL] = []
        result = manager.execute(plan: plan, target: entry, risk: risk, confirmation: confirmation, sourceFilesForBackup: dbFiles)
        if let result {
            history.insert(result, at: 0)
        }
    }

    func openBackupFolder() {
        guard let rawPath = result?.backupPath, !rawPath.isEmpty else {
            NSWorkspace.shared.activateFileViewerSelecting([manager.backupRootPath()])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: rawPath)])
    }
}
