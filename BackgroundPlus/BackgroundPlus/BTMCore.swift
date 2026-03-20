import Foundation
import os

private let btmDataSourceLog = Logger(subsystem: "cn.magicdian.BackgroundPlus", category: "BTMDataSource")

enum BTMEntryType: String, CaseIterable, Codable {
    case app
    case daemon
    case agent
    case developer
    case unknown
}

enum BTMEntryCategory: String, CaseIterable, Codable {
    case loginItem
    case backgroundItem
    case unknown
}

struct BTMEntry: Identifiable, Hashable, Codable {
    let uuid: String
    let identifier: String
    let name: String
    let type: BTMEntryType
    let category: BTMEntryCategory
    let disposition: String
    let url: String
    let generation: Int
    let bundleID: String
    let parentIdentifier: String?
    let embeddedItemIdentifiers: [String]

    var id: String { identifier + "#" + uuid }
}

struct EntryGraph: Equatable {
    let parentToChildren: [String: [String]]
}

enum DeleteMode: String, CaseIterable, Codable {
    case safe
    case advanced
}

enum OrphanRisk: String, Codable {
    case none
    case possible
    case high
}

enum RiskLevel: String, CaseIterable, Codable {
    case low
    case medium
    case high

    func elevated() -> RiskLevel {
        switch self {
        case .low:
            return .medium
        case .medium:
            return .high
        case .high:
            return .high
        }
    }
}

enum ConfirmationLevel: String, Codable {
    case single
    case double
    case textChallenge
}

struct PlannedEntry: Identifiable, Codable, Equatable {
    let identifier: String
    let type: BTMEntryType
    let required: Bool

    var id: String { identifier }
}

struct DryRunSummary: Codable, Equatable {
    let totalPlanned: Int
    let byType: [BTMEntryType: Int]
    let hasParent: Bool
    let childCount: Int
    let orphanRisk: OrphanRisk
    let humanText: String
}

struct DeletePlan: Codable, Equatable {
    let targetIdentifier: String
    let mode: DeleteMode
    let plannedEntries: [PlannedEntry]
    let manualAdjustment: Bool
    let dryRunSummary: DryRunSummary
}

enum BackupStatus: String, Codable {
    case success
    case failed
}

enum ExecutionStatus: String, Codable {
    case success
    case failed
    case rolledBack
}

enum PostCheckStatus: String, Codable {
    case pass
    case warn
    case fail
    case notRun
}

struct OperationRecord: Identifiable, Codable {
    let operationId: String
    let timestamp: Date
    let operationType: String
    let targetIdentifier: String
    let targetType: BTMEntryType
    let riskLevel: RiskLevel
    let confirmationLevel: ConfirmationLevel
    let dryRunSummary: DryRunSummary
    let plannedEntries: [PlannedEntry]
    let backupPath: String
    let backupStatus: BackupStatus
    let executionStatus: ExecutionStatus
    let postCheckStatus: PostCheckStatus
    let postCheckSummary: String
    let errorCode: String?
    let errorMessage: String?

    var id: String { operationId }
}

struct LoadResult {
    let entries: [BTMEntry]
    let projection: BTMEntryProjection
    let sourceMethod: BTMListSourceMethod
    let parseIncomplete: Bool
    let unknownFieldCount: Int
    let unknownCategoryCount: Int
}

enum BTMListSourceMethod: String, Codable {
    case btmFile = "btm_file"
    case sfltool = "sfltool"
    case fixture = "fixture"
    case unknown = "unknown"
}

struct DumpFetchResult {
    let dump: String
    let sourceMethod: BTMListSourceMethod
}

struct BTMParseOutput {
    let entries: [BTMEntry]
    let parseIncomplete: Bool
    let unknownFieldCount: Int
    let unknownCategoryCount: Int
}

struct BTMEntryProjection: Equatable {
    let allItems: [BTMEntry]
    let loginItems: [BTMEntry]
    let backgroundItems: [BTMEntry]
    let unknownItems: [BTMEntry]

    static let empty = BTMEntryProjection(allItems: [], loginItems: [], backgroundItems: [], unknownItems: [])
}

enum BTMCoreError: LocalizedError {
    case parseFailed
    case backupFailed
    case deleteFailed
    case helperNotInstalled
    case helperCommunicationFailed
    case helperProtocolMismatch
    case helperCapabilitiesUnavailable
    case helperVersionMismatch
    case helperWriteUnsupported
    case helperExecutionFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .parseFailed:
            return "btm.error.parse_incomplete"
        case .backupFailed:
            return "btm.error.backup_failed"
        case .deleteFailed:
            return "btm.error.execution_failed"
        case .helperNotInstalled:
            return "btm.helper.error.not_installed"
        case .helperCommunicationFailed:
            return "btm.helper.error.communication"
        case .helperProtocolMismatch:
            return "btm.helper.error.protocol_mismatch"
        case .helperCapabilitiesUnavailable:
            return "btm.helper.error.capabilities_unavailable"
        case .helperVersionMismatch:
            return "btm.helper.error.version_mismatch"
        case .helperWriteUnsupported:
            return "btm.helper.error.write_unsupported"
        case let .helperExecutionFailed(message):
            return message
        case .permissionDenied:
            return "btm.error.permission_denied"
        }
    }
}

struct BTMDumpParser {
    func parse(_ raw: String) -> BTMParseOutput {
        let lines = raw.split(whereSeparator: \.isNewline).map(String.init)
        var chunks: [[String]] = []
        var current: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isEntryStart(trimmed) {
                if !current.isEmpty {
                    chunks.append(current)
                }
                current = [line]
            } else if !current.isEmpty {
                current.append(line)
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }

        var entries: [BTMEntry] = []
        var unknownFieldCount = 0
        var unknownCategoryCount = 0

        for chunk in chunks {
            var uuid = ""
            var name = ""
            var typeRaw = ""
            var disposition = ""
            var identifier = ""
            var url = ""
            var generation = 0
            var bundleID = ""
            var parentIdentifier: String?
            var embedded: [String] = []
            var inEmbeddedSection = false

            for source in chunk {
                let trimmed = source.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Embedded Item Identifiers:") {
                    inEmbeddedSection = true
                    continue
                }
                if inEmbeddedSection, trimmed.hasPrefix("#"), let value = trimmed.split(separator: ":", maxSplits: 1).last {
                    let identifierValue = value.trimmingCharacters(in: .whitespaces)
                    if !identifierValue.isEmpty {
                        embedded.append(identifierValue)
                    }
                    continue
                }
                if inEmbeddedSection, !trimmed.hasPrefix("#") {
                    inEmbeddedSection = false
                }

                if let value = fieldValue("UUID:", in: trimmed) {
                    uuid = value
                } else if let value = fieldValue("Name:", in: trimmed) {
                    name = value
                } else if let value = fieldValue("Type:", in: trimmed) {
                    typeRaw = value
                } else if let value = fieldValue("Disposition:", in: trimmed) {
                    disposition = value
                } else if let value = fieldValue("Identifier:", in: trimmed) {
                    identifier = value
                } else if let value = fieldValue("URL:", in: trimmed) {
                    url = value
                } else if let value = fieldValue("Generation:", in: trimmed) {
                    generation = Int(value) ?? 0
                } else if let value = fieldValue("Bundle Identifier:", in: trimmed) {
                    bundleID = value
                } else if let value = fieldValue("Parent Identifier:", in: trimmed) {
                    parentIdentifier = value
                }
            }

            if identifier.isEmpty {
                unknownFieldCount += 1
                continue
            }
            let parsedType = parseType(typeRaw)
            let entry = BTMEntry(
                uuid: uuid,
                identifier: identifier,
                name: name,
                type: parsedType,
                category: classifyCategory(
                    type: parsedType,
                    identifier: identifier,
                    url: url,
                    bundleID: bundleID
                ),
                disposition: disposition,
                url: url,
                generation: generation,
                bundleID: bundleID,
                parentIdentifier: parentIdentifier,
                embeddedItemIdentifiers: embedded
            )
            if entry.category == .unknown {
                unknownCategoryCount += 1
            }
            if entry.type == .unknown || entry.url.isEmpty {
                unknownFieldCount += 1
            }
            entries.append(entry)
        }

        return BTMParseOutput(
            entries: entries,
            parseIncomplete: unknownFieldCount > 0,
            unknownFieldCount: unknownFieldCount,
            unknownCategoryCount: unknownCategoryCount
        )
    }

    private func isEntryStart(_ line: String) -> Bool {
        line.hasPrefix("#") && line.hasSuffix(":")
    }

    private func fieldValue(_ key: String, in line: String) -> String? {
        guard line.hasPrefix(key) else { return nil }
        return String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
    }

    private func parseType(_ raw: String) -> BTMEntryType {
        let lower = raw.lowercased()
        if lower.contains("legacy agent") || lower.contains("agent") { return .agent }
        if lower.contains("legacy daemon") || lower.contains("daemon") { return .daemon }
        if lower.contains("developer") { return .developer }
        if lower.contains("app") { return .app }
        return .unknown
    }

    private func classifyCategory(type: BTMEntryType, identifier: String, url: String, bundleID: String) -> BTMEntryCategory {
        let lowerURL = url.lowercased()
        let lowerIdentifier = identifier.lowercased()
        let isLaunchServicePath = lowerURL.contains("launchdaemons")
            || lowerURL.contains("launchagents")
            || lowerURL.contains("privilegedhelpertools")
        if isLaunchServicePath {
            return .backgroundItem
        }

        // In modern BTM data, helper login-item bundles under Contents/Library/LoginItems
        // usually represent app background services, not "open at login" app entries.
        if lowerURL.contains("contents/library/loginitems/")
            || lowerIdentifier.hasPrefix("4.") {
            return .backgroundItem
        }

        switch type {
        case .app:
            if lowerURL.contains(".app/") || !bundleID.isEmpty {
                return .loginItem
            }
            return .unknown
        case .daemon, .agent, .developer:
            return .backgroundItem
        case .unknown:
            return .unknown
        }
    }
}

struct EntryProjector {
    func project(entries: [BTMEntry]) -> BTMEntryProjection {
        let allItems = entries
        var loginItems: [BTMEntry] = []
        var backgroundItems: [BTMEntry] = []
        var unknownItems: [BTMEntry] = []

        for entry in entries {
            switch entry.category {
            case .loginItem:
                loginItems.append(entry)
            case .backgroundItem:
                backgroundItems.append(entry)
            case .unknown:
                unknownItems.append(entry)
            }
        }
        return BTMEntryProjection(
            allItems: allItems,
            loginItems: loginItems,
            backgroundItems: backgroundItems,
            unknownItems: unknownItems
        )
    }
}

struct DeletePlanner {
    func buildGraph(entries: [BTMEntry]) -> EntryGraph {
        var map: [String: [String]] = [:]
        for entry in entries {
            guard let parent = entry.parentIdentifier else { continue }
            map[parent, default: []].append(entry.identifier)
        }
        return EntryGraph(parentToChildren: map)
    }

    func makePlan(target: BTMEntry, entries: [BTMEntry], mode: DeleteMode, excludedOptionalIdentifiers: Set<String> = []) -> DeletePlan {
        let graph = buildGraph(entries: entries)
        var required: Set<String> = [target.identifier]
        var optional: Set<String> = []

        if target.type == .app {
            for embedded in target.embeddedItemIdentifiers {
                required.insert(embedded)
            }
            for child in graph.parentToChildren[target.identifier] ?? [] {
                required.insert(child)
            }
        }

        if target.type == .developer {
            for child in graph.parentToChildren[target.identifier] ?? [] {
                optional.insert(child)
            }
        }

        if target.type == .daemon || target.type == .agent {
            optional.removeAll()
        }

        var manualAdjustment = false
        if mode == .advanced, !excludedOptionalIdentifiers.isEmpty {
            optional.subtract(excludedOptionalIdentifiers)
            manualAdjustment = true
        }

        let plannedIdentifiers = Array(required.union(optional)).sorted()
        let index = Dictionary(uniqueKeysWithValues: entries.map { ($0.identifier, $0) })
        let plannedEntries = plannedIdentifiers.map { identifier in
            PlannedEntry(identifier: identifier, type: index[identifier]?.type ?? .unknown, required: required.contains(identifier))
        }

        let byType = Dictionary(grouping: plannedEntries, by: \.type).mapValues(\.count)
        let orphanRisk = resolveOrphanRisk(target: target, planned: Set(plannedIdentifiers))
        let summary = DryRunSummary(
            totalPlanned: plannedEntries.count,
            byType: byType,
            hasParent: target.parentIdentifier != nil,
            childCount: plannedEntries.count - 1,
            orphanRisk: orphanRisk,
            humanText: "btm.confirm.dry_run.summary"
        )
        return DeletePlan(
            targetIdentifier: target.identifier,
            mode: mode,
            plannedEntries: plannedEntries,
            manualAdjustment: manualAdjustment,
            dryRunSummary: summary
        )
    }

    private func resolveOrphanRisk(target: BTMEntry, planned: Set<String>) -> OrphanRisk {
        if target.type == .unknown {
            return .high
        }
        if target.type == .app {
            let missing = target.embeddedItemIdentifiers.filter { !planned.contains($0) }
            return missing.isEmpty ? .none : .high
        }
        if target.type == .developer {
            return .possible
        }
        return .none
    }
}

struct RiskAssessor {
    func assess(plan: DeletePlan, parseIncomplete: Bool) -> (RiskLevel, ConfirmationLevel) {
        var risk: RiskLevel = .low
        let types = Set(plan.plannedEntries.map(\.type))

        if plan.plannedEntries.count >= 3 || types.contains(.unknown) || plan.dryRunSummary.orphanRisk == .high {
            risk = .high
        } else if types.contains(.app) || plan.dryRunSummary.childCount > 0 || plan.dryRunSummary.orphanRisk == .possible {
            risk = .medium
        }

        if parseIncomplete {
            risk = risk.elevated()
        }
        if plan.manualAdjustment {
            risk = .high
        }

        let confirmation: ConfirmationLevel
        switch risk {
        case .low:
            confirmation = .single
        case .medium:
            confirmation = .double
        case .high:
            confirmation = .textChallenge
        }
        return (risk, confirmation)
    }
}

struct PostCheckResult {
    let status: PostCheckStatus
    let summaryKey: String
}

protocol BTMDataSource {
    func fetchDump() throws -> DumpFetchResult
}

struct SFLToolDataSource: BTMDataSource {
    func fetchDump() throws -> DumpFetchResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sfltool")
        process.arguments = ["dumpbtm"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
            throw BTMCoreError.parseFailed
        }
        return DumpFetchResult(dump: raw, sourceMethod: .sfltool)
    }
}

struct FixtureDataSource: BTMDataSource {
    func fetchDump() throws -> DumpFetchResult {
        DumpFetchResult(dump: BTMFixture.sampleDump, sourceMethod: .fixture)
    }
}

struct PrivilegedHelperDataSource: BTMDataSource {
    let helperClient: PrivilegedHelperClient

    func fetchDump() throws -> DumpFetchResult {
        btmDataSourceLog.info("Fetching dump via helper")
        return try helperClient.fetchBTMDump()
    }
}

protocol BTMDatabaseAdapter {
    func deleteEntries(identifiers: [String]) throws
    func remainingRelatedEntries(for identifiers: [String]) throws -> [String]
}

final class InMemoryDatabaseAdapter: BTMDatabaseAdapter {
    private var storedIdentifiers: Set<String>

    init(seed: [String]) {
        self.storedIdentifiers = Set(seed)
    }

    func deleteEntries(identifiers: [String]) throws {
        for identifier in identifiers {
            storedIdentifiers.remove(identifier)
        }
    }

    func remainingRelatedEntries(for identifiers: [String]) throws -> [String] {
        identifiers.filter { storedIdentifiers.contains($0) }
    }
}

final class HelperWriteDatabaseAdapter: BTMDatabaseAdapter {
    private let helperClient: PrivilegedHelperClient
    private let parser = BTMDumpParser()

    init(helperClient: PrivilegedHelperClient) {
        self.helperClient = helperClient
    }

    func deleteEntries(identifiers: [String]) throws {
        for identifier in identifiers {
            let request = HelperWriteRequest(
                version: helperWriteRouteVersion,
                operation: .delete,
                identifier: identifier,
                modeRawValue: DeleteMode.safe.rawValue,
                enabled: nil
            )
            try helperClient.performWrite(request)
        }
    }

    func remainingRelatedEntries(for identifiers: [String]) throws -> [String] {
        let dumpResult = try helperClient.fetchBTMDump()
        let entries = parser.parse(dumpResult.dump).entries
        let existing = Set(entries.map(\.identifier))
        return identifiers.filter { existing.contains($0) }
    }
}

protocol BackupManaging {
    func createBackup(sourceFiles: [URL], operationId: String, targetIdentifier: String) throws -> URL
    var backupRoot: URL { get }
}

struct BackupManager: BackupManaging {
    let backupRoot: URL

    init(base: URL? = nil) {
        if let base {
            backupRoot = base
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            backupRoot = appSupport.appendingPathComponent("BackgroundPlus/Backups", isDirectory: true)
        }
    }

    func createBackup(sourceFiles: [URL], operationId: String, targetIdentifier: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let safeTarget = targetIdentifier.replacingOccurrences(of: "/", with: "_")
        let folder = backupRoot.appendingPathComponent("\(formatter.string(from: Date()))_delete_\(safeTarget)_\(operationId)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for source in sourceFiles where FileManager.default.fileExists(atPath: source.path) {
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return folder
    }
}

final class BTMManager {
    private let parser = BTMDumpParser()
    private let projector = EntryProjector()
    private let planner = DeletePlanner()
    private let riskAssessor = RiskAssessor()
    private let source: BTMDataSource
    private let database: BTMDatabaseAdapter
    private let backupManager: BackupManaging

    init(source: BTMDataSource, database: BTMDatabaseAdapter, backupManager: BackupManaging) {
        self.source = source
        self.database = database
        self.backupManager = backupManager
    }

    func loadEntries() throws -> LoadResult {
        let dumpResult = try source.fetchDump()
        let parse = parser.parse(dumpResult.dump)
        let projection = projector.project(entries: parse.entries)
        return LoadResult(
            entries: parse.entries,
            projection: projection,
            sourceMethod: dumpResult.sourceMethod,
            parseIncomplete: parse.parseIncomplete,
            unknownFieldCount: parse.unknownFieldCount,
            unknownCategoryCount: parse.unknownCategoryCount
        )
    }

    func projectEntries(_ entries: [BTMEntry]) -> BTMEntryProjection {
        projector.project(entries: entries)
    }

    func buildPlan(target: BTMEntry, entries: [BTMEntry], mode: DeleteMode, excludedOptionalIdentifiers: Set<String> = [], parseIncomplete: Bool) -> (DeletePlan, RiskLevel, ConfirmationLevel) {
        let plan = planner.makePlan(target: target, entries: entries, mode: mode, excludedOptionalIdentifiers: excludedOptionalIdentifiers)
        let (risk, confirmation) = riskAssessor.assess(plan: plan, parseIncomplete: parseIncomplete)
        return (plan, risk, confirmation)
    }

    func execute(plan: DeletePlan, target: BTMEntry, risk: RiskLevel, confirmation: ConfirmationLevel, sourceFilesForBackup: [URL]) -> OperationRecord {
        let operationId = UUID().uuidString
        let now = Date()

        let backupURL: URL
        do {
            backupURL = try backupManager.createBackup(sourceFiles: sourceFilesForBackup, operationId: operationId, targetIdentifier: plan.targetIdentifier)
        } catch {
            return OperationRecord(
                operationId: operationId,
                timestamp: now,
                operationType: "delete-entry",
                targetIdentifier: plan.targetIdentifier,
                targetType: target.type,
                riskLevel: risk,
                confirmationLevel: confirmation,
                dryRunSummary: plan.dryRunSummary,
                plannedEntries: plan.plannedEntries,
                backupPath: "",
                backupStatus: .failed,
                executionStatus: .failed,
                postCheckStatus: .notRun,
                postCheckSummary: "btm.error.backup_failed",
                errorCode: "backup_failed",
                errorMessage: error.localizedDescription
            )
        }

        do {
            let identifiers = plan.plannedEntries.map(\.identifier)
            try database.deleteEntries(identifiers: identifiers)
            let remaining = try database.remainingRelatedEntries(for: identifiers)
            let postCheck = makePostCheck(remainingCount: remaining.count)
            return OperationRecord(
                operationId: operationId,
                timestamp: now,
                operationType: "delete-entry",
                targetIdentifier: plan.targetIdentifier,
                targetType: target.type,
                riskLevel: risk,
                confirmationLevel: confirmation,
                dryRunSummary: plan.dryRunSummary,
                plannedEntries: plan.plannedEntries,
                backupPath: backupURL.path,
                backupStatus: .success,
                executionStatus: postCheck.status == .pass ? .success : .failed,
                postCheckStatus: postCheck.status,
                postCheckSummary: postCheck.summaryKey,
                errorCode: postCheck.status == .pass ? nil : "post_check_failed",
                errorMessage: nil
            )
        } catch {
            return OperationRecord(
                operationId: operationId,
                timestamp: now,
                operationType: "delete-entry",
                targetIdentifier: plan.targetIdentifier,
                targetType: target.type,
                riskLevel: risk,
                confirmationLevel: confirmation,
                dryRunSummary: plan.dryRunSummary,
                plannedEntries: plan.plannedEntries,
                backupPath: backupURL.path,
                backupStatus: .success,
                executionStatus: .rolledBack,
                postCheckStatus: .notRun,
                postCheckSummary: "btm.result.rollback.title",
                errorCode: "delete_failed",
                errorMessage: error.localizedDescription
            )
        }
    }

    func backupRootPath() -> URL {
        backupManager.backupRoot
    }

    private func makePostCheck(remainingCount: Int) -> PostCheckResult {
        if remainingCount == 0 {
            return PostCheckResult(status: .pass, summaryKey: "btm.result.postcheck.pass")
        }
        return PostCheckResult(status: .fail, summaryKey: "btm.result.postcheck.fail")
    }
}
