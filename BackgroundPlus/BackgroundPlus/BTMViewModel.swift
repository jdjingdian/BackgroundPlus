import AppKit
import Combine
import Foundation
import SwiftUI

enum EntryLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case requiresHelper
    case error(String)
}

final class BTMViewModel: ObservableObject {
    @Published var entries: [BTMEntry] = []
    @Published var parseIncomplete = false
    @Published var selectedEntryID: String?
    @Published var mode: DeleteMode = .safe
    @Published var result: OperationRecord?
    @Published var history: [OperationRecord] = []
    @Published var errorKey: String?
    @Published var searchText = ""
    @Published var helperState: HelperInstallState = .notInstalled
    @Published var helperErrorMessage = ""
    @Published var entryLoadingState: EntryLoadingState = .idle

    private let manager: BTMManager
    private let installManager: HelperInstallManager

    init(manager: BTMManager? = nil, installManager: HelperInstallManager = HelperInstallManager()) {
        self.manager = manager ?? BTMViewModel.defaultManager()
        self.installManager = installManager
        self.helperState = installManager.persistedState()
    }

    static func defaultManager() -> BTMManager {
        let useFixture = ProcessInfo.processInfo.arguments.contains("--ui-test-fixture")
        let source: BTMDataSource
        if useFixture {
            source = FixtureDataSource()
        } else {
            source = PrivilegedHelperDataSource(helperClient: XPCPrivilegedHelperClient())
        }
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

    var shouldShowInstallPrompt: Bool {
        helperState != .installed
    }

    func refreshHelperState() {
        helperState = installManager.refreshState()
    }

    func installHelper() {
        helperErrorMessage = ""
        helperState = .installing
        do {
            helperState = try installManager.install()
        } catch let error as HelperInstallError {
            helperState = .failed
            let key = error.errorDescription ?? "btm.helper.error.install_failed"
            helperErrorMessage = String(localized: String.LocalizationValue(key))
        } catch {
            helperState = .failed
            helperErrorMessage = error.localizedDescription
        }
    }

    func load() {
        entryLoadingState = .loading
        refreshHelperState()

        let useFixture = ProcessInfo.processInfo.arguments.contains("--ui-test-fixture")
        if !useFixture, helperState != .installed {
            entries = []
            selectedEntryID = nil
            errorKey = nil
            parseIncomplete = false
            entryLoadingState = .requiresHelper
            return
        }

        Task.detached(priority: .userInitiated) { [weak self, manager] in
            do {
                let result = try manager.loadEntries()
                await MainActor.run {
                    guard let self else { return }
                    self.entries = result.entries
                    self.parseIncomplete = result.parseIncomplete
                    self.errorKey = nil
                    if self.selectedEntryID == nil {
                        self.selectedEntryID = self.entries.first?.id
                    }
                    self.entryLoadingState = self.entries.isEmpty ? .empty : .loaded
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    if let key = (error as? LocalizedError)?.errorDescription {
                        self.errorKey = key
                        self.entryLoadingState = .error(key)
                    } else {
                        self.errorKey = "btm.error.unknown"
                        self.entryLoadingState = .error("btm.error.unknown")
                    }
                }
            }
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
