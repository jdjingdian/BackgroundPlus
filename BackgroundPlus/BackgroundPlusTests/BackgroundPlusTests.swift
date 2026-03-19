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

        #expect(output.entries.count == 2)
        #expect(output.entries.contains(where: { $0.identifier == "2.cn.magicdian.staticrouter" && $0.type == .app }))
        #expect(output.entries.contains(where: { $0.identifier == "16.cn.magicdian.staticrouter.service" && $0.parentIdentifier == "2.cn.magicdian.staticrouter" }))
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
        #expect(BTMCoreError.permissionDenied.errorDescription == "btm.error.permission_denied")
    }

    @Test func helperDataSourcePipelineFeedsParser() throws {
        let source = PrivilegedHelperDataSource(helperClient: MockHelperClient(dump: BTMFixture.sampleDump))
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

    func fetchBTMDump() throws -> String {
        dump
    }
}

private struct FailingBackupManager: BackupManaging {
    let backupRoot = URL(fileURLWithPath: NSTemporaryDirectory())

    func createBackup(sourceFiles: [URL], operationId: String, targetIdentifier: String) throws -> URL {
        throw NSError(domain: "test", code: 1)
    }
}
