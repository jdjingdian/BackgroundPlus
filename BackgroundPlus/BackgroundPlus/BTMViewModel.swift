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

enum BTMSidebarItem: Hashable {
    case loginItems
    case backgroundItems
}

final class BTMViewModel: ObservableObject {
    @Published var entries: [BTMEntry] = []
    @Published private(set) var projectedEntries: BTMEntryProjection = .empty
    @Published var parseIncomplete = false
    @Published var classificationIncomplete = false
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
    @Published var selectedSidebarItem: BTMSidebarItem? = .loginItems {
        didSet {
            syncSelectionForSidebarChange()
        }
    }
    @Published var customDetailEntryID: String?
    @Published var entryEnabledOverrides: [String: Bool] = [:]
    @Published var customDetailUnavailableMessageKey: String?

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

    var customDetailEntry: BTMEntry? {
        guard let customDetailEntryID else { return nil }
        return entries.first(where: { $0.id == customDetailEntryID })
    }

    var filteredEntries: [BTMEntry] {
        let candidates = entriesForSelectedSidebar
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter {
            $0.identifier.localizedCaseInsensitiveContains(searchText)
                || $0.bundleID.localizedCaseInsensitiveContains(searchText)
                || $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var emptyStateKeyForSelectedSidebar: String {
        switch selectedSidebarItem {
        case .loginItems:
            return "btm.list.empty.login_items"
        case .backgroundItems, .none:
            return "btm.list.empty.background_items"
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
                self.projectedEntries = result.projection
                self.parseIncomplete = result.parseIncomplete
                self.classificationIncomplete = result.unknownCategoryCount > 0
                self.applyUITestOverrides()
                self.projectedEntries = manager.projectEntries(self.entries)
                self.classificationIncomplete = !self.projectedEntries.unknownItems.isEmpty
                self.errorKey = nil
                self.syncSelectionForSidebarChange()
                let validIDs = Set(self.entries.map(\.id))
                self.entryEnabledOverrides = self.entryEnabledOverrides.filter { validIDs.contains($0.key) }
                if let customDetailEntryID = self.customDetailEntryID, !validIDs.contains(customDetailEntryID) {
                    self.customDetailEntryID = nil
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

    func enabledState(for entry: BTMEntry) -> Bool {
        if let override = entryEnabledOverrides[entry.id] {
            return override
        }
        return inferredEnabledState(from: entry.disposition)
    }

    func setEnabledState(_ isEnabled: Bool, for entry: BTMEntry) {
        entryEnabledOverrides[entry.id] = isEnabled
        selectedEntryID = entry.id
    }

    func openCustomDetail(for entry: BTMEntry) {
        guard canOpenCustomDetail(for: entry) else {
            customDetailUnavailableMessageKey = "btm.custom_detail.unavailable"
            return
        }
        selectedEntryID = entry.id
        customDetailEntryID = entry.id
    }

    func closeCustomDetail() {
        customDetailEntryID = nil
    }

    func canOpenCustomDetail(for entry: BTMEntry) -> Bool {
        let hasIdentifier = !entry.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBundleID = !entry.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidFileURL = URL(string: entry.url)?.isFileURL == true
        return hasIdentifier || hasBundleID || hasValidFileURL
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
        projectedEntries = .empty
        selectedEntryID = nil
        customDetailEntryID = nil
        parseIncomplete = false
        classificationIncomplete = false
        entryLoadingState = .requiresHelper
    }

    private func inferredEnabledState(from disposition: String) -> Bool {
        let lowercased = disposition.lowercased()
        if lowercased.contains("disabled") {
            return false
        }
        if lowercased.contains("enabled") {
            return true
        }
        return true
    }

    private func applyUITestOverrides() {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("--ui-test-parse-incomplete-banner") {
            parseIncomplete = true
        }

        if args.contains("--ui-test-many-entries") {
            entries = makeExpandedEntries(from: entries, targetCount: 40)
        }

        if args.contains("--ui-test-invalid-detail-entry") {
            let invalid = BTMEntry(
                uuid: "ui-test-invalid-entry",
                identifier: "",
                name: "Invalid Entry For UI Test",
                type: .unknown,
                category: .unknown,
                disposition: "[enabled]",
                url: "not-a-file-url",
                generation: 0,
                bundleID: "",
                parentIdentifier: nil,
                embeddedItemIdentifiers: []
            )
            entries.insert(invalid, at: 0)
        }
    }

    private func makeExpandedEntries(from baseEntries: [BTMEntry], targetCount: Int) -> [BTMEntry] {
        guard !baseEntries.isEmpty else { return baseEntries }
        var expanded: [BTMEntry] = []
        expanded.reserveCapacity(targetCount)

        for index in 0..<targetCount {
            let source = baseEntries[index % baseEntries.count]
            let entry = BTMEntry(
                uuid: "\(source.uuid)-ui-\(index)",
                identifier: "\(source.identifier)-\(index)",
                name: "\(source.name) Long Long Long Name \(index) For Truncation Boundary Validation",
                type: source.type,
                category: source.category,
                disposition: source.disposition,
                url: index.isMultiple(of: 3) ? "not-a-file-url" : source.url,
                generation: source.generation,
                bundleID: source.bundleID,
                parentIdentifier: source.parentIdentifier,
                embeddedItemIdentifiers: source.embeddedItemIdentifiers
            )
            expanded.append(entry)
        }

        return expanded
    }

    private var entriesForSelectedSidebar: [BTMEntry] {
        switch selectedSidebarItem {
        case .loginItems:
            return projectedEntries.loginItems
        case .backgroundItems, .none:
            return projectedEntries.backgroundItems
        }
    }

    private func syncSelectionForSidebarChange() {
        let visibleIDs = Set(filteredEntries.map(\.id))
        if let selectedEntryID, visibleIDs.contains(selectedEntryID) {
            return
        }
        selectedEntryID = filteredEntries.first?.id
    }
}
