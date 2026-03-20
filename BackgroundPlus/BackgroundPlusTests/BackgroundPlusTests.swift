//
//  BackgroundPlusTests.swift
//  BackgroundPlusTests
//
//  Created by 经典 on 2026/3/19.
//

import Testing
@testable import BackgroundPlus
import Foundation

@MainActor
struct BackgroundPlusTests {

    @Test func parserParsesFixture() {
        let parser = BTMDumpParser()
        let output = parser.parse(BTMFixture.sampleDump)
        let hasLoginApp = output.entries.contains { entry in
            entry.identifier == "2.cn.magicdian.staticrouter"
                && entry.type == .app
                && entry.category == .loginItem
        }
        let hasBackgroundDaemon = output.entries.contains { entry in
            entry.identifier == "16.cn.magicdian.staticrouter.service"
                && entry.parentIdentifier == "2.cn.magicdian.staticrouter"
                && entry.category == .backgroundItem
        }

        #expect(output.entries.count == 2)
        #expect(hasLoginApp)
        #expect(hasBackgroundDaemon)
    }

    @Test func deletePlanAndRiskForAppIsMedium() {
        let parser = BTMDumpParser()
        let entries = parser.parse(BTMFixture.sampleDump).entries
        let target = entries.first(where: { $0.identifier == "2.cn.magicdian.staticrouter" })!

        let planner = DeletePlanner()
        let plan = planner.makePlan(target: target, entries: entries, mode: .safe)
        let risk = RiskAssessor().assess(plan: plan, parseIncomplete: false)

        #expect(plan.plannedEntries.count == 2)
        #expect(plan.plannedEntries.contains(where: { $0.identifier == "16.cn.magicdian.staticrouter.service" && $0.required }))
        #expect(risk.0 == .medium)
        #expect(risk.1 == .double)
    }

    @Test func backupFailureBlocksExecution() {
        let manager = BTMManager(
            source: FixtureDataSource(),
            database: InMemoryDatabaseAdapter(seed: ["2.cn.magicdian.staticrouter", "16.cn.magicdian.staticrouter.service"]),
            backupManager: FailingBackupManager()
        )
        let load = try! manager.loadEntries()
        let target = load.entries.first(where: { $0.identifier == "2.cn.magicdian.staticrouter" })!
        let planning = manager.buildPlan(target: target, entries: load.entries, mode: .safe, parseIncomplete: load.parseIncomplete)
        let record = manager.execute(plan: planning.0, target: target, risk: planning.1, confirmation: planning.2, sourceFilesForBackup: [])

        #expect(record.backupStatus == .failed)
        #expect(record.executionStatus == .failed)
        #expect(record.errorCode == "backup_failed")
    }

    @Test func localizationFilesHaveSameKeys() throws {
        let base = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BackgroundPlus")
        let en = base.appendingPathComponent("en.lproj/Localizable.strings")
        let zh = base.appendingPathComponent("zh-Hans.lproj/Localizable.strings")

        let enKeys = try parseKeys(from: en)
        let zhKeys = try parseKeys(from: zh)

        #expect(enKeys == zhKeys)
        #expect(enKeys.contains("btm.list.title"))
    }

    @Test func helperErrorMappingsAreStable() {
        #expect(BTMCoreError.helperNotInstalled.errorDescription == "btm.helper.error.not_installed")
        #expect(BTMCoreError.helperCommunicationFailed.errorDescription == "btm.helper.error.communication")
        #expect(BTMCoreError.helperProtocolMismatch.errorDescription == "btm.helper.error.protocol_mismatch")
        #expect(BTMCoreError.helperVersionMismatch.errorDescription == "btm.helper.error.version_mismatch")
        #expect(BTMCoreError.helperCapabilitiesUnavailable.errorDescription == "btm.helper.error.capabilities_unavailable")
        #expect(BTMCoreError.helperWriteUnsupported.errorDescription == "btm.helper.error.write_unsupported")
        #expect(BTMCoreError.permissionDenied.errorDescription == "btm.error.permission_denied")
    }

    @Test func parserFlagsIncompleteButKeepsEntries() {
        let parser = BTMDumpParser()
        let raw = """
 #1:
                 UUID: TEST-UUID-1
                 Name: Demo
                 Type: mystery (0x999)
          Disposition: [enabled] (0x1)
           Identifier: demo.entry
                  URL: file:///Applications/Demo.app/
           Generation: 1
    Bundle Identifier: com.demo.entry
"""

        let output = parser.parse(raw)
        #expect(output.parseIncomplete)
        #expect(output.entries.count == 1)
        #expect(output.unknownCategoryCount == 1)
    }

    @Test func parseWarningBannerStateAggregatesParseAndClassificationFlags() {
        let viewModel = BTMViewModel(
            manager: BTMManager(
                source: FixtureDataSource(),
                database: InMemoryDatabaseAdapter(seed: []),
                backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
            ),
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)
            )
        )

        viewModel.parseIncomplete = false
        viewModel.classificationIncomplete = false
        #expect(viewModel.parseWarningBannerState == .none)
        #expect(viewModel.parseWarningBannerMessageKey == nil)

        viewModel.parseIncomplete = true
        viewModel.classificationIncomplete = false
        #expect(viewModel.parseWarningBannerState == .parseOnly)
        #expect(viewModel.parseWarningBannerMessageKey == "btm.error.parse_incomplete")

        viewModel.parseIncomplete = false
        viewModel.classificationIncomplete = true
        #expect(viewModel.parseWarningBannerState == .classificationOnly)
        #expect(viewModel.parseWarningBannerMessageKey == "btm.error.classification_incomplete")

        viewModel.parseIncomplete = true
        viewModel.classificationIncomplete = true
        #expect(viewModel.parseWarningBannerState == .parseAndClassification)
        #expect(viewModel.parseWarningBannerMessageKey == "btm.error.parse_and_classification_incomplete")
    }

    @Test func projectorKeepsUnknownEntriesOutOfBackgroundListAndPreservesAllItems() {
        let entries: [BTMEntry] = [
            BTMEntry(
                uuid: "app",
                identifier: "2.example.app",
                name: "Example App",
                type: .app,
                category: .loginItem,
                disposition: "[enabled]",
                url: "file:///Applications/Example.app/",
                generation: 1,
                bundleID: "example.app",
                parentIdentifier: nil,
                embeddedItemIdentifiers: []
            ),
            BTMEntry(
                uuid: "unknown",
                identifier: "unknown.entry",
                name: "Unknown",
                type: .unknown,
                category: .unknown,
                disposition: "[enabled]",
                url: "not-a-file-url",
                generation: 1,
                bundleID: "",
                parentIdentifier: nil,
                embeddedItemIdentifiers: []
            )
        ]

        let projection = EntryProjector().project(entries: entries)
        #expect(projection.allItems.count == 2)
        #expect(projection.loginItems.count == 1)
        #expect(projection.backgroundItems.isEmpty)
        #expect(projection.unknownItems.count == 1)
    }

    @Test func customDetailAvailabilityRequiresIdentifierBundleOrFileURL() {
        let viewModel = BTMViewModel(
            manager: BTMManager(
                source: FixtureDataSource(),
                database: InMemoryDatabaseAdapter(seed: []),
                backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
            ),
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)
            )
        )

        let invalid = BTMEntry(
            uuid: "invalid",
            identifier: "",
            name: "invalid",
            type: .unknown,
            category: .unknown,
            disposition: "",
            url: "not-a-file-url",
            generation: 0,
            bundleID: "",
            parentIdentifier: nil,
            embeddedItemIdentifiers: []
        )
        let valid = BTMEntry(
            uuid: "valid",
            identifier: "id.valid",
            name: "valid",
            type: .app,
            category: .loginItem,
            disposition: "",
            url: "not-a-file-url",
            generation: 0,
            bundleID: "",
            parentIdentifier: nil,
            embeddedItemIdentifiers: []
        )

        #expect(!viewModel.canOpenCustomDetail(for: invalid))
        #expect(viewModel.canOpenCustomDetail(for: valid))
    }

    @Test func helperDataSourcePipelineFeedsParser() throws {
        let source = PrivilegedHelperDataSource(
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)
            )
        )
        let manager = BTMManager(
            source: source,
            database: InMemoryDatabaseAdapter(seed: [
                "2.cn.magicdian.staticrouter",
                "16.cn.magicdian.staticrouter.service"
            ]),
            backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
        )

        let loaded = try manager.loadEntries()
        #expect(loaded.entries.count == 2)
        #expect(loaded.entries.first?.identifier == "2.cn.magicdian.staticrouter")
        #expect(loaded.projection.loginItems.count == 1)
        #expect(loaded.projection.backgroundItems.count == 1)
    }

    @Test func compatibilityValidatorDetectsOldHelper() {
        let validator = HelperCompatibilityValidator(
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "0.9.0", interfaceVersion: 1)
            ),
            appVersionProvider: { "1.0.0" }
        )

        let result = validator.validate()
        #expect(
            result
                == .incompatible(
                    .versionMismatch(expectedAppVersion: "1.0.0", actualHelperVersion: "0.9.0")
                )
        )
    }

    @Test func compatibilityValidatorTreatsReadFailureAsIncompatible() {
        let validator = HelperCompatibilityValidator(
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: nil,
                capabilityError: BTMCoreError.helperCommunicationFailed
            ),
            appVersionProvider: { "1.0.0" }
        )

        let result = validator.validate()
        #expect(result == .incompatible(.capabilityReadFailed))
    }

    @Test func compatibilityValidatorRecoversAfterForceRefresh() {
        var state = 0
        let validator = HelperCompatibilityValidator(
            helperClient: FlappingHelperClient {
                defer { state += 1 }
                if state == 0 {
                    return .failure(BTMCoreError.helperCommunicationFailed)
                }
                return .success(HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1))
            },
            appVersionProvider: { "1.0.0" }
        )

        #expect(validator.validate() == .incompatible(.capabilityReadFailed))
        #expect(validator.validate(forceRefresh: true) == .compatible(HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)))
    }

    @Test func readOnlyModeRequiresInstalledHelperAndUnsupportedWrite() {
        let viewModel = BTMViewModel(
            manager: BTMManager(
                source: FixtureDataSource(),
                database: InMemoryDatabaseAdapter(seed: []),
                backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
            ),
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)
            )
        )

        viewModel.helperState = .installed
        viewModel.writeOperationsSupported = false
        viewModel.toggleOperationsSupported = false
        #expect(viewModel.isReadOnlyMode)
        #expect(viewModel.readOnlyBannerMessageKey == "btm.helper.error.write_unsupported")

        viewModel.writeOperationsSupported = true
        viewModel.toggleOperationsSupported = false
        #expect(viewModel.isReadOnlyMode)
        #expect(viewModel.readOnlyBannerMessageKey == "btm.helper.error.toggle_unsupported")

        viewModel.toggleOperationsSupported = true
        #expect(!viewModel.isReadOnlyMode)
        #expect(viewModel.readOnlyBannerMessageKey == nil)
    }

    @Test func setEnabledStateBlockedInReadOnlyMode() {
        let viewModel = BTMViewModel(
            manager: BTMManager(
                source: FixtureDataSource(),
                database: InMemoryDatabaseAdapter(seed: []),
                backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
            ),
            helperClient: MockHelperClient(
                dump: BTMFixture.sampleDump,
                capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1)
            )
        )
        let entry = BTMEntry(
            uuid: "readonly-toggle",
            identifier: "readonly.toggle",
            name: "Readonly Toggle",
            type: .app,
            category: .loginItem,
            disposition: "[enabled]",
            url: "file:///Applications/Readonly.app/",
            generation: 1,
            bundleID: "readonly.toggle",
            parentIdentifier: nil,
            embeddedItemIdentifiers: []
        )

        viewModel.writeOperationsSupported = false
        viewModel.setEnabledState(false, for: entry)
        #expect(viewModel.errorKey == "btm.helper.error.toggle_unsupported")
        #expect(viewModel.entryEnabledOverrides[entry.id] == nil)
    }

    @Test func helperWriteDatabaseAdapterDeleteSuccess() throws {
        let helper = MockHelperClient(
            dump: "",
            capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1, supportsWriteOperations: true, writeSchemaVersion: 1)
        )
        let adapter = HelperWriteDatabaseAdapter(helperClient: helper)
        try adapter.deleteEntries(identifiers: ["target.id"])
        let remaining = try adapter.remainingRelatedEntries(for: ["target.id"])
        #expect(remaining.isEmpty)
    }

    @Test func helperWriteDatabaseAdapterDeleteFailure() {
        let helper = MockHelperClient(
            dump: BTMFixture.sampleDump,
            capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1, supportsWriteOperations: true, writeSchemaVersion: 1),
            writeError: BTMCoreError.helperExecutionFailed("write failed")
        )
        let adapter = HelperWriteDatabaseAdapter(helperClient: helper)

        #expect(throws: BTMCoreError.self) {
            try adapter.deleteEntries(identifiers: ["target.id"])
        }
    }

    @Test func toggleWriteFailureRollsBackOverride() async {
        let helper = MockHelperClient(
            dump: BTMFixture.sampleDump,
            capabilities: HelperCapabilities(helperVersion: "1.0.0", interfaceVersion: 1, supportsWriteOperations: true, writeSchemaVersion: 1),
            writeError: BTMCoreError.helperCommunicationFailed
        )
        let viewModel = BTMViewModel(
            manager: BTMManager(
                source: FixtureDataSource(),
                database: InMemoryDatabaseAdapter(seed: []),
                backupManager: BackupManager(base: URL(fileURLWithPath: NSTemporaryDirectory()))
            ),
            helperClient: helper
        )
        let entry = BTMEntry(
            uuid: "toggle-failure",
            identifier: "toggle.failure",
            name: "Toggle Failure",
            type: .app,
            category: .loginItem,
            disposition: "[enabled]",
            url: "file:///Applications/ToggleFailure.app/",
            generation: 1,
            bundleID: "toggle.failure",
            parentIdentifier: nil,
            embeddedItemIdentifiers: []
        )

        viewModel.writeOperationsSupported = true
        viewModel.toggleOperationsSupported = true
        viewModel.entries = [entry]
        viewModel.setEnabledState(false, for: entry)
        try? await Task.sleep(nanoseconds: 120_000_000)

        #expect(viewModel.enabledState(for: entry))
        #expect(viewModel.errorKey == "btm.helper.error.communication")
    }

    @Test func btmFixtureDeleteOnCopiedFileRemovesTargetIdentifier() throws {
        guard let fixtureURL = btmFixtureFileURL() else {
            return
        }
        let workingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackgroundItems-v13-copy-\(UUID().uuidString).btm")
        defer { try? FileManager.default.removeItem(at: workingURL) }
        try FileManager.default.copyItem(at: fixtureURL, to: workingURL)

        let targetIdentifier = "8.com.tencent.Lemon.trash"
        let countsBefore = try BTMArchiveTestSupport.identifierCounts(in: workingURL)
        #expect(!countsBefore.isEmpty)
        guard let removedCount = countsBefore[targetIdentifier] else {
            Issue.record("fixture missing expected identifier: \(targetIdentifier)")
            return
        }

        let deleted = try BTMArchiveTestSupport.removeIdentifier(targetIdentifier, from: workingURL)
        #expect(deleted)

        let countsAfter = try BTMArchiveTestSupport.identifierCounts(in: workingURL)
        let remainingCount = countsAfter[targetIdentifier] ?? 0
        #expect(remainingCount == 0)
        #expect(countsAfter.values.reduce(0, +) == countsBefore.values.reduce(0, +) - removedCount)
    }

    private func parseKeys(from fileURL: URL) throws -> Set<String> {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let keys = lines.compactMap { line -> String? in
            guard let start = line.firstIndex(of: "\"") else { return nil }
            guard let end = line[line.index(after: start)...].firstIndex(of: "\"") else { return nil }
            return String(line[line.index(after: start)..<end])
        }
        return Set(keys)
    }

    private func btmFixtureFileURL() -> URL? {
        let rootBySourceFile = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootByWorkingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        let candidates = [
            rootBySourceFile.appendingPathComponent("BackgroundPlusBTMMockData/BackgroundItems-v13.btm"),
            rootByWorkingDirectory.appendingPathComponent("BackgroundPlusBTMMockData/BackgroundItems-v13.btm"),
            rootByWorkingDirectory.appendingPathComponent("BackgroundPlus/BackgroundPlusBTMMockData/BackgroundItems-v13.btm")
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            if let identifiers = try? BTMArchiveTestSupport.identifiers(in: candidate), !identifiers.isEmpty {
                return candidate
            }
        }
        return nil
    }

}

private struct MockHelperClient: PrivilegedHelperClient {
    let dump: String
    let capabilities: HelperCapabilities?
    var capabilityError: Error?
    var writeError: Error?

    func fetchBTMDump() throws -> DumpFetchResult {
        DumpFetchResult(dump: dump, sourceMethod: .fixture)
    }

    func fetchHelperCapabilities() throws -> HelperCapabilities {
        if let capabilityError {
            throw capabilityError
        }
        guard let capabilities else {
            throw BTMCoreError.helperCapabilitiesUnavailable
        }
        return capabilities
    }

    func performWrite(_ request: HelperWriteRequest) throws {
        if let writeError {
            throw writeError
        }
    }
}

private struct FlappingHelperClient: PrivilegedHelperClient {
    let next: () -> Result<HelperCapabilities, Error>

    func fetchBTMDump() throws -> DumpFetchResult {
        DumpFetchResult(dump: BTMFixture.sampleDump, sourceMethod: .fixture)
    }

    func fetchHelperCapabilities() throws -> HelperCapabilities {
        switch next() {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }

    func performWrite(_ request: HelperWriteRequest) throws {}
}

private struct FailingBackupManager: BackupManaging {
    let backupRoot = URL(fileURLWithPath: NSTemporaryDirectory())

    func createBackup(sourceFiles: [URL], operationId: String, targetIdentifier: String) throws -> URL {
        throw NSError(domain: "test", code: 1)
    }
}

private enum BTMArchiveTestSupport {
    static func identifierCounts(in fileURL: URL) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for identifier in try identifiers(in: fileURL) {
            counts[identifier, default: 0] += 1
        }
        return counts
    }

    static func identifiers(in fileURL: URL) throws -> [String] {
        let data = try Data(contentsOf: fileURL)
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let root = try PropertyListSerialization.propertyList(
            from: data,
            options: [.mutableContainersAndLeaves],
            format: &format
        ) as? NSMutableDictionary,
              let objects = root["$objects"] as? NSMutableArray else {
            return []
        }

        var ids: [String] = []
        ids.reserveCapacity(objects.count)

        for object in objects {
            guard let dict = object as? [String: Any] else { continue }
            guard let identifierUID = uidValue(from: dict["identifier"]) else { continue }
            guard identifierUID >= 0, identifierUID < objects.count else { continue }
            guard let identifier = objects[identifierUID] as? String, !identifier.isEmpty else { continue }
            ids.append(identifier)
        }

        return ids
    }

    static func removeIdentifier(_ identifier: String, from storeURL: URL) throws -> Bool {
        let data = try Data(contentsOf: storeURL)
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let root = try PropertyListSerialization.propertyList(
            from: data,
            options: [.mutableContainersAndLeaves],
            format: &format
        ) as? NSMutableDictionary else {
            return false
        }
        guard let objects = root["$objects"] as? NSMutableArray else {
            return false
        }

        let objectSnapshot = objects.map { $0 }
        var targetUIDs = Set<Int>()
        for (index, object) in objectSnapshot.enumerated() {
            guard let dict = object as? [String: Any] else { continue }
            guard let identifierUID = uidValue(from: dict["identifier"]) else { continue }
            guard identifierUID >= 0, identifierUID < objectSnapshot.count else { continue }
            if (objectSnapshot[identifierUID] as? String) == identifier {
                targetUIDs.insert(index)
            }
        }

        guard !targetUIDs.isEmpty else { return false }
        var changed = false

        for case let dict as NSMutableDictionary in objects {
            for case let key as String in dict.allKeys {
                let value = dict[key]
                if let uid = uidValue(from: value), targetUIDs.contains(uid) {
                    dict[key] = makeUID(0)
                    changed = true
                    continue
                }

                if let arrayValue = value as? NSMutableArray {
                    let filtered = arrayValue.filter { element in
                        guard let uid = uidValue(from: element) else { return true }
                        return !targetUIDs.contains(uid)
                    }
                    if filtered.count != arrayValue.count {
                        arrayValue.removeAllObjects()
                        arrayValue.addObjects(from: filtered)
                        changed = true
                    }
                }
            }
        }

        for uid in targetUIDs where uid < objects.count {
            objects[uid] = "$null"
            changed = true
        }

        guard changed else { return false }
        let updatedData = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        try updatedData.write(to: storeURL, options: .atomic)
        return true
    }

    private static func makeUID(_ value: Int) -> [String: Any] {
        ["CF$UID": value]
    }

    private static func uidValue(from candidate: Any?) -> Int? {
        if let dict = candidate as? [String: Any], let uid = dict["CF$UID"] as? Int {
            return uid
        }
        if let object = candidate as AnyObject?,
           object.responds(to: NSSelectorFromString("value")),
           let uid = object.value(forKey: "value") as? Int {
            return uid
        }
        return nil
    }
}
