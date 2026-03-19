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

enum HelperCompatibilityState: Equatable {
    case unknown
    case compatible(helperVersion: String)
    case versionMismatch(expectedAppVersion: String, actualHelperVersion: String)
    case capabilityReadFailed

    var requiresReinstall: Bool {
        switch self {
        case .versionMismatch, .capabilityReadFailed:
            return true
        case .unknown, .compatible:
            return false
        }
    }
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
    @Published var helperCompatibilityState: HelperCompatibilityState = .unknown
    @Published var helperRecovered = false

    private let manager: BTMManager
    private let installManager: HelperInstallManager
    private let compatibilityValidator: HelperCompatibilityValidator

    init(
        manager: BTMManager? = nil,
        installManager: HelperInstallManager = HelperInstallManager(),
        helperClient: PrivilegedHelperClient = XPCPrivilegedHelperClient(),
        compatibilityValidator: HelperCompatibilityValidator? = nil
    ) {
        self.manager = manager ?? BTMViewModel.defaultManager(helperClient: helperClient)
        self.installManager = installManager
        self.compatibilityValidator = compatibilityValidator ?? HelperCompatibilityValidator(helperClient: helperClient)
        self.helperState = installManager.persistedState()
    }

    static func defaultManager(helperClient: PrivilegedHelperClient) -> BTMManager {
        let useFixture = ProcessInfo.processInfo.arguments.contains("--ui-test-fixture")
        let source: BTMDataSource
        if useFixture {
            source = FixtureDataSource()
        } else {
            source = PrivilegedHelperDataSource(helperClient: helperClient)
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
        helperState != .installed || helperCompatibilityState.requiresReinstall
    }

    var compatibilityStatusKey: String {
        switch helperCompatibilityState {
        case .unknown:
            return "btm.settings.compatibility.unknown"
        case .compatible:
            return helperRecovered ? "btm.settings.compatibility.recovered" : "btm.settings.compatibility.ok"
        case .versionMismatch:
            return "btm.settings.compatibility.version_mismatch"
        case .capabilityReadFailed:
            return "btm.settings.compatibility.read_failed"
        }
    }

    var compatibilityWarningTitleKey: String {
        switch helperCompatibilityState {
        case .versionMismatch:
            return "btm.helper.warning.version_mismatch.title"
        case .capabilityReadFailed:
            return "btm.helper.warning.read_failed.title"
        case .unknown, .compatible:
            return ""
        }
    }

    var compatibilityWarningBody: String {
        switch helperCompatibilityState {
        case let .versionMismatch(expected, actual):
            return String(format: localized("btm.helper.warning.version_mismatch.body"), expected, actual)
        case .capabilityReadFailed:
            return localized("btm.helper.warning.read_failed.body")
        case .unknown, .compatible:
            return ""
        }
    }

    func refreshHelperState() {
        helperState = installManager.refreshState()
        if helperState != .installed {
            compatibilityValidator.invalidate()
            helperCompatibilityState = .unknown
            helperRecovered = false
        }
    }

    func installHelper() {
        helperErrorMessage = ""
        compatibilityValidator.invalidate()
        helperState = .installing
        do {
            helperState = try installManager.install()
            if helperState == .installed {
                _ = evaluateCompatibility(forceRefresh: true)
            }
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
            moveToRequiresHelperState()
            return
        }

        if !useFixture, !evaluateCompatibility() {
            moveToRequiresHelperState()
            return
        }

        Task(priority: .userInitiated) { [weak self, manager] in
            do {
                let result = try manager.loadEntries()
                guard let self else { return }
                self.entries = result.entries
                self.parseIncomplete = result.parseIncomplete
                self.errorKey = nil
                if self.selectedEntryID == nil {
                    self.selectedEntryID = self.entries.first?.id
                }
                self.entryLoadingState = self.entries.isEmpty ? .empty : .loaded
            } catch {
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

    func planning(for entry: BTMEntry) -> (DeletePlan, RiskLevel, ConfirmationLevel) {
        manager.buildPlan(target: entry, entries: entries, mode: mode, parseIncomplete: parseIncomplete)
    }

    func executeDelete(entry: BTMEntry) {
        if !evaluateCompatibility() {
            moveToRequiresHelperState()
            errorKey = BTMCoreError.helperVersionMismatch.errorDescription
            return
        }
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

    private func evaluateCompatibility(forceRefresh: Bool = false) -> Bool {
        let wasIncompatible = helperCompatibilityState.requiresReinstall
        let validation = compatibilityValidator.validate(forceRefresh: forceRefresh)
        switch validation {
        case let .compatible(capabilities):
            helperCompatibilityState = .compatible(helperVersion: capabilities.helperVersion)
            helperRecovered = wasIncompatible
            return true
        case let .incompatible(issue):
            helperRecovered = false
            switch issue {
            case let .versionMismatch(expectedAppVersion, actualHelperVersion):
                helperCompatibilityState = .versionMismatch(
                    expectedAppVersion: expectedAppVersion,
                    actualHelperVersion: actualHelperVersion
                )
                errorKey = BTMCoreError.helperVersionMismatch.errorDescription
            case .interfaceMismatch:
                helperCompatibilityState = .capabilityReadFailed
                errorKey = BTMCoreError.helperCapabilitiesUnavailable.errorDescription
            case .capabilityReadFailed:
                helperCompatibilityState = .capabilityReadFailed
                errorKey = BTMCoreError.helperCapabilitiesUnavailable.errorDescription
            }
            return false
        }
    }

    private func moveToRequiresHelperState() {
        entries = []
        selectedEntryID = nil
        parseIncomplete = false
        entryLoadingState = .requiresHelper
    }
}
