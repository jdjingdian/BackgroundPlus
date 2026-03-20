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

}

private struct MockHelperClient: PrivilegedHelperClient {
    let dump: String
    let capabilities: HelperCapabilities?
    var capabilityError: Error?

    func fetchBTMDump() throws -> String {
        dump
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
}

private struct FlappingHelperClient: PrivilegedHelperClient {
    let next: () -> Result<HelperCapabilities, Error>

    func fetchBTMDump() throws -> String {
        BTMFixture.sampleDump
    }

    func fetchHelperCapabilities() throws -> HelperCapabilities {
        switch next() {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

private struct FailingBackupManager: BackupManaging {
    let backupRoot = URL(fileURLWithPath: NSTemporaryDirectory())

    func createBackup(sourceFiles: [URL], operationId: String, targetIdentifier: String) throws -> URL {
        throw NSError(domain: "test", code: 1)
    }
}
