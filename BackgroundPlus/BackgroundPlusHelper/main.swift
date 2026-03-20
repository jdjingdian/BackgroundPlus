import Foundation
import SecureXPC
import os
import Darwin

private let helperBundleIdentifier = "cn.magicdian.BackgroundPlus.helper"
private let helperProtocolVersion = 1
private let helperCapabilitiesRouteVersion = 1
private let helperWriteRouteVersion = 1
private let helperUninstallRouteVersion = 1
private let helperInterfaceVersion = 1
private let helperLog = Logger(subsystem: helperBundleIdentifier, category: "HelperServer")

private struct HelperDumpRequest: Codable {
    let version: Int
}

private struct HelperDumpResponse: Codable {
    let version: Int
    let dump: String
    let sourceMethodRawValue: String
    let errorCode: String?
    let errorMessage: String?
}

private struct HelperCapabilitiesRequest: Codable {
    let version: Int
}

private struct HelperCapabilitiesResponse: Codable {
    let version: Int
    let helperVersion: String
    let interfaceVersion: Int
    let supportsWriteOperations: Bool
    let writeSchemaVersion: Int
    let errorCode: String?
    let errorMessage: String?
}

private enum HelperWriteOperation: String, Codable {
    case toggle
    case delete
}

private struct HelperWriteRequest: Codable {
    let version: Int
    let operation: HelperWriteOperation
    let identifier: String
    let modeRawValue: String?
    let enabled: Bool?
}

private struct HelperWriteResponse: Codable {
    let version: Int
    let errorCode: String?
    let errorMessage: String?
}

private struct HelperUninstallRequest: Codable {
    let version: Int
}

private struct HelperUninstallResponse: Codable {
    let version: Int
    let errorCode: String?
    let errorMessage: String?
}

private let helperDumpRoute = XPCRoute
    .named("btm", "fetchDump", "v1")
    .withMessageType(HelperDumpRequest.self)
    .withReplyType(HelperDumpResponse.self)

private let helperCapabilitiesRoute = XPCRoute
    .named("helper", "capabilities", "v1")
    .withMessageType(HelperCapabilitiesRequest.self)
    .withReplyType(HelperCapabilitiesResponse.self)

private let helperWriteRoute = XPCRoute
    .named("btm", "write", "v1")
    .withMessageType(HelperWriteRequest.self)
    .withReplyType(HelperWriteResponse.self)

private let helperUninstallRoute = XPCRoute
    .named("helper", "selfUninstall", "v1")
    .withMessageType(HelperUninstallRequest.self)
    .withReplyType(HelperUninstallResponse.self)

private enum BTMWriteError: LocalizedError {
    case noStoreFiles
    case malformedStore
    case targetNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noStoreFiles:
            return "no_store_files"
        case .malformedStore:
            return "malformed_store"
        case let .targetNotFound(identifier):
            return "target_not_found:\(identifier)"
        }
    }
}

private enum DumpSourceMethod: String {
    case btmFile = "btm_file"
    case sfltool = "sfltool"
}

private struct BTMStoreProbeResult {
    let stores: [URL]
    let readAllowed: Bool
    let writeAllowed: Bool
}

private struct DumpDiagnostics {
    let entryCount: Int
    let enabledCount: Int
    let disabledCount: Int
    let unknownDispositionCount: Int
    let typeCounts: [String: Int]
    let dispositionSamples: [String: Int]
    let identifiers: [String]
}

private func supportsWriteOperations() -> Bool {
    let args = ProcessInfo.processInfo.arguments
    if args.contains("--helper-disable-write") {
        helperLog.info("Write support disabled by runtime arg --helper-disable-write")
        return false
    }
    let probe = probeBTMStoreAccess()
    let supported = !probe.stores.isEmpty && probe.readAllowed && probe.writeAllowed
    helperLog.info(
        "Write support probe result=\(supported, privacy: .public) readAllowed=\(probe.readAllowed, privacy: .public) writeAllowed=\(probe.writeAllowed, privacy: .public) storeCount=\(probe.stores.count)"
    )
    return supported
}

private func shouldCompareDumpSources() -> Bool {
    let args = ProcessInfo.processInfo.arguments
    if args.contains("--helper-disable-dump-compare") {
        return false
    }
    return true
}

private func dispositionState(_ raw: String) -> String {
    let lower = raw.lowercased()
    if lower.contains("disabled") {
        return "disabled"
    }
    if lower.contains("enabled") {
        return "enabled"
    }
    return "unknown"
}

private func compactMapCounts(_ map: [String: Int], top: Int) -> String {
    map
        .sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        .prefix(top)
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: ",")
}

private func collectDumpDiagnostics(from dump: String) -> DumpDiagnostics {
    let lines = dump.split(whereSeparator: \.isNewline).map(String.init)

    struct ScratchEntry {
        var identifier = ""
        var disposition = ""
        var type = "unknown"
    }

    func finalize(
        _ entry: ScratchEntry?,
        entryCount: inout Int,
        enabledCount: inout Int,
        disabledCount: inout Int,
        unknownDispositionCount: inout Int,
        typeCounts: inout [String: Int],
        dispositionSamples: inout [String: Int],
        identifiers: inout [String]
    ) {
        guard let entry, !entry.identifier.isEmpty else { return }
        entryCount += 1
        identifiers.append(entry.identifier)
        typeCounts[entry.type, default: 0] += 1
        if !entry.disposition.isEmpty {
            dispositionSamples[entry.disposition, default: 0] += 1
        }
        switch dispositionState(entry.disposition) {
        case "enabled":
            enabledCount += 1
        case "disabled":
            disabledCount += 1
        default:
            unknownDispositionCount += 1
        }
    }

    var current: ScratchEntry?
    var entryCount = 0
    var enabledCount = 0
    var disabledCount = 0
    var unknownDispositionCount = 0
    var typeCounts: [String: Int] = [:]
    var dispositionSamples: [String: Int] = [:]
    var identifiers: [String] = []

    for source in lines {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#"), trimmed.hasSuffix(":") {
            finalize(
                current,
                entryCount: &entryCount,
                enabledCount: &enabledCount,
                disabledCount: &disabledCount,
                unknownDispositionCount: &unknownDispositionCount,
                typeCounts: &typeCounts,
                dispositionSamples: &dispositionSamples,
                identifiers: &identifiers
            )
            current = ScratchEntry()
            continue
        }

        guard var entry = current else { continue }

        if trimmed.hasPrefix("Identifier:") {
            entry.identifier = String(trimmed.dropFirst("Identifier:".count)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.hasPrefix("Disposition:") {
            entry.disposition = String(trimmed.dropFirst("Disposition:".count)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.hasPrefix("Type:") {
            entry.type = String(trimmed.dropFirst("Type:".count)).trimmingCharacters(in: .whitespaces)
        }

        current = entry
    }

    finalize(
        current,
        entryCount: &entryCount,
        enabledCount: &enabledCount,
        disabledCount: &disabledCount,
        unknownDispositionCount: &unknownDispositionCount,
        typeCounts: &typeCounts,
        dispositionSamples: &dispositionSamples,
        identifiers: &identifiers
    )

    return DumpDiagnostics(
        entryCount: entryCount,
        enabledCount: enabledCount,
        disabledCount: disabledCount,
        unknownDispositionCount: unknownDispositionCount,
        typeCounts: typeCounts,
        dispositionSamples: dispositionSamples,
        identifiers: identifiers
    )
}

private func logDumpDiagnostics(_ diagnostics: DumpDiagnostics, label: String) {
    let typeSummary = compactMapCounts(diagnostics.typeCounts, top: 8)
    let dispositionSummary = compactMapCounts(diagnostics.dispositionSamples, top: 8)
    let identifiersPreview = diagnostics.identifiers.prefix(8).joined(separator: ",")
    helperLog.info(
        """
        Dump diagnostics source=\(label, privacy: .public) entries=\(diagnostics.entryCount, privacy: .public) enabled=\(diagnostics.enabledCount, privacy: .public) disabled=\(diagnostics.disabledCount, privacy: .public) unknownDisposition=\(diagnostics.unknownDispositionCount, privacy: .public) types=\(typeSummary, privacy: .public) dispositionSamples=\(dispositionSummary, privacy: .public) identifiersPreview=\(identifiersPreview, privacy: .public)
        """
    )
}

private func logDumpComparison(primary: DumpDiagnostics, fallback: DumpDiagnostics) {
    let primarySet = Set(primary.identifiers)
    let fallbackSet = Set(fallback.identifiers)
    let onlyPrimary = Array(primarySet.subtracting(fallbackSet)).sorted().prefix(12).joined(separator: ",")
    let onlyFallback = Array(fallbackSet.subtracting(primarySet)).sorted().prefix(12).joined(separator: ",")

    helperLog.info(
        """
        Dump compare btm_file_vs_sfltool entriesDelta=\(primary.entryCount - fallback.entryCount, privacy: .public) enabledDelta=\(primary.enabledCount - fallback.enabledCount, privacy: .public) disabledDelta=\(primary.disabledCount - fallback.disabledCount, privacy: .public) unknownDispositionDelta=\(primary.unknownDispositionCount - fallback.unknownDispositionCount, privacy: .public) onlyInBTMFile=\(onlyPrimary, privacy: .public) onlyInSFLTool=\(onlyFallback, privacy: .public)
        """
    )
}

private func accessAllowed(_ path: String, mode: Int32) -> Bool {
    access(path, mode) == 0
}

private func errnoText(_ code: Int32) -> String {
    guard let cString = strerror(code) else { return "unknown" }
    return String(cString: cString)
}

private func logPOSIXAccess(_ path: String, mode: Int32, label: String) {
    errno = 0
    let result = access(path, mode)
    if result == 0 {
        helperLog.info("POSIX access check success label=\(label, privacy: .public) path=\(path, privacy: .public)")
        return
    }

    let code = errno
    helperLog.error(
        "POSIX access check failed label=\(label, privacy: .public) path=\(path, privacy: .public) errno=\(code, privacy: .public) message=\(errnoText(code), privacy: .public)"
    )
}

private func logPOSIXDirectoryOpen(_ path: String) {
    errno = 0
    guard let dir = opendir(path) else {
        let code = errno
        helperLog.error(
            "POSIX opendir failed path=\(path, privacy: .public) errno=\(code, privacy: .public) message=\(errnoText(code), privacy: .public)"
        )
        return
    }

    helperLog.info("POSIX opendir success path=\(path, privacy: .public)")
    closedir(dir)
}

private func logPOSIXStat(_ path: String) {
    var st = stat()
    errno = 0
    let result = stat(path, &st)
    if result == 0 {
        helperLog.info(
            "POSIX stat success path=\(path, privacy: .public) mode=0\(String(st.st_mode, radix: 8), privacy: .public) uid=\(st.st_uid, privacy: .public) gid=\(st.st_gid, privacy: .public)"
        )
        return
    }

    let code = errno
    helperLog.error(
        "POSIX stat failed path=\(path, privacy: .public) errno=\(code, privacy: .public) message=\(errnoText(code), privacy: .public)"
    )
}

@discardableResult
private func runCommandProbe(executable: String, arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    } catch {
        return (-1, "launch_error: \(error.localizedDescription)")
    }
}

private func logExternalProbe(_ root: URL) {
    let ls = runCommandProbe(executable: "/bin/ls", arguments: ["-lde@", root.path])
    let lsOutput = ls.output.trimmingCharacters(in: .whitespacesAndNewlines)
    helperLog.info(
        "External probe ls status=\(ls.status, privacy: .public) path=\(root.path, privacy: .public) output=\(lsOutput, privacy: .public)"
    )

    let statProbe = runCommandProbe(executable: "/usr/bin/stat", arguments: ["-x", root.path])
    let statOutput = statProbe.output.trimmingCharacters(in: .whitespacesAndNewlines)
    helperLog.info(
        "External probe stat status=\(statProbe.status, privacy: .public) path=\(root.path, privacy: .public) output=\(statOutput, privacy: .public)"
    )
}

private func logFileManagerProbe(_ root: URL) {
    let path = root.path
    let readable = FileManager.default.isReadableFile(atPath: path)
    let writable = FileManager.default.isWritableFile(atPath: path)
    let executable = FileManager.default.isExecutableFile(atPath: path)
    helperLog.info(
        "FileManager probe path=\(path, privacy: .public) readable=\(readable, privacy: .public) writable=\(writable, privacy: .public) executable=\(executable, privacy: .public)"
    )
}

private func logDirectoryProbeMatrix(_ root: URL) {
    let path = root.path
    helperLog.info("Access matrix probe start path=\(path, privacy: .public)")
    logPOSIXStat(path)
    logPOSIXAccess(path, mode: F_OK, label: "F_OK")
    logPOSIXAccess(path, mode: R_OK, label: "R_OK")
    logPOSIXAccess(path, mode: X_OK, label: "X_OK")
    logPOSIXDirectoryOpen(path)
    logFileManagerProbe(root)
    logExternalProbe(root)
}

private func probeBTMStoreAccess() -> BTMStoreProbeResult {
    helperLog.info("BTM access probe started uid=\(getuid()) euid=\(geteuid())")

    let roots = [
        URL(fileURLWithPath: "/private/var/db/com.apple.backgroundtaskmanagement", isDirectory: true),
        URL(fileURLWithPath: "/var/db/com.apple.backgroundtaskmanagement", isDirectory: true)
    ]

    var urls: [URL] = []
    for root in roots {
        helperLog.info("Probing BTM store directory: \(root.path, privacy: .public)")
        logDirectoryProbeMatrix(root)
        do {
            urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            helperLog.info("Directory list succeeded: \(root.path, privacy: .public), itemCount=\(urls.count)")
            break
        } catch {
            helperLog.error("Failed to list BTM store directory \(root.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    let stores = urls
        .filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("BackgroundItems-v") && name.hasSuffix(".btm")
        }
        .sorted { lhs, rhs in
            versionNumber(in: lhs.lastPathComponent) > versionNumber(in: rhs.lastPathComponent)
        }

    let names = stores.map(\.lastPathComponent).joined(separator: ",")
    helperLog.info("Discovered \(stores.count) BTM store candidate(s): \(names, privacy: .public)")

    guard let first = stores.first else {
        return BTMStoreProbeResult(stores: [], readAllowed: false, writeAllowed: false)
    }

    let readAllowed = accessAllowed(first.path, mode: R_OK)
    let writeAllowed = accessAllowed(first.path, mode: W_OK)
    helperLog.info(
        "BTM store access check path=\(first.path, privacy: .public) readAllowed=\(readAllowed, privacy: .public) writeAllowed=\(writeAllowed, privacy: .public)"
    )

    return BTMStoreProbeResult(stores: stores, readAllowed: readAllowed, writeAllowed: writeAllowed)
}

private func discoverBTMStoreFiles() -> [URL] {
    probeBTMStoreAccess().stores
}

private func versionNumber(in filename: String) -> Int {
    let prefix = "BackgroundItems-v"
    let suffix = ".btm"
    guard filename.hasPrefix(prefix), filename.hasSuffix(suffix) else { return 0 }
    let start = filename.index(filename.startIndex, offsetBy: prefix.count)
    let end = filename.index(filename.endIndex, offsetBy: -suffix.count)
    return Int(filename[start..<end]) ?? 0
}

private func makeUID(_ value: Int) -> [String: Any] {
    ["CF$UID": value]
}

private func uidValue(from candidate: Any?) -> Int? {
    if let dict = candidate as? [String: Any], let uid = dict["CF$UID"] as? Int {
        return uid
    }
    if let object = candidate as AnyObject?,
       object.responds(to: NSSelectorFromString("value")),
       let uid = object.value(forKey: "value") as? Int {
        return uid
    }
    if let object = candidate {
        let text = String(describing: object)
        if let range = text.range(of: "value = ") {
            let suffix = text[range.upperBound...]
            let digits = suffix.prefix { $0.isNumber }
            if !digits.isEmpty, let uid = Int(digits) {
                return uid
            }
        }
    }
    return nil
}

private func stringFromObjects(_ objects: [Any], uid: Int) -> String? {
    guard uid >= 0, uid < objects.count else { return nil }
    return objects[uid] as? String
}

private func objectFromObjects(_ objects: [Any], uid: Int) -> Any? {
    guard uid >= 0, uid < objects.count else { return nil }
    return objects[uid]
}

private func formatUUID(_ data: Data) -> String {
    guard data.count == 16 else { return "" }
    let bytes = [UInt8](data)
    return String(
        format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    )
}

private func resolvedObject(for key: String, in dict: [String: Any], objects: [Any]) -> Any? {
    guard let value = dict[key] else { return nil }
    if let uid = uidValue(from: value) {
        return objectFromObjects(objects, uid: uid)
    }
    return value
}

private func entryTypeText(typeRaw: Int) -> String {
    switch typeRaw {
    case 1:
        return "daemon (0x1)"
    case 2:
        return "app (0x2)"
    case 3:
        return "agent (0x3)"
    case 4:
        return "app (0x4)"
    case 0x10:
        return "daemon (0x10)"
    case 0x20:
        return "developer (0x20)"
    case 0x40:
        return "spotlight (0x40)"
    case 0x800:
        return "quicklook (0x800)"
    case 0x10008:
        return "legacy agent (0x10008)"
    case 0x10010:
        return "legacy daemon (0x10010)"
    default:
        return "unknown (0x\(String(typeRaw, radix: 16)))"
    }
}

private func dispositionText(raw: Int) -> String {
    let enabled = (raw & 0x1) != 0
    let allowed = (raw & 0x2) != 0
    let visible = (raw & 0x4) != 0
    let notified = (raw & 0x8) != 0

    let enabledText = enabled ? "enabled" : "disabled"
    let allowedText = allowed ? "allowed" : "disallowed"
    let visibleText = visible ? "visible" : "hidden"
    let notifiedText = notified ? "notified" : "not notified"

    return "[\(enabledText), \(allowedText), \(visibleText), \(notifiedText)] (0x\(String(raw, radix: 16)))"
}

private func urlText(from value: Any?, objects: [Any]) -> String {
    if let raw = value as? String {
        return raw
    }
    guard let dict = value as? [String: Any] else { return "" }
    if let relativeUID = uidValue(from: dict["NS.relative"]) {
        return stringFromObjects(objects, uid: relativeUID) ?? ""
    }
    return ""
}

private func uuidText(from value: Any?) -> String {
    guard let dict = value as? [String: Any], let bytes = dict["NS.uuidbytes"] as? Data else { return "" }
    return formatUUID(bytes)
}

private func identifiersInItems(_ value: Any?, objects: [Any]) -> [String] {
    guard let dict = value as? [String: Any],
          let itemUIDsRaw = dict["NS.objects"] as? [Any] else {
        return []
    }

    var embedded: [String] = []
    for raw in itemUIDsRaw {
        guard let uid = uidValue(from: raw),
              let item = objectFromObjects(objects, uid: uid) as? [String: Any],
              let identifierUID = uidValue(from: item["identifier"]),
              let identifier = stringFromObjects(objects, uid: identifierUID),
              !identifier.isEmpty else {
            continue
        }
        embedded.append(identifier)
    }
    return embedded
}

private func convertBTMStoreToDump(_ storeURL: URL) throws -> String {
    let data = try Data(contentsOf: storeURL)
    var format = PropertyListSerialization.PropertyListFormat.binary
    guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any],
          let objects = root["$objects"] as? [Any] else {
        throw BTMWriteError.malformedStore
    }

    var lines: [String] = []
    var index = 1

    for object in objects {
        guard let dict = object as? [String: Any] else { continue }
        guard let identifierUID = uidValue(from: dict["identifier"]),
              let identifier = stringFromObjects(objects, uid: identifierUID),
              !identifier.isEmpty else {
            continue
        }

        let name = (resolvedObject(for: "name", in: dict, objects: objects) as? String) ?? ""
        let typeRaw = (dict["type"] as? Int) ?? 0
        let dispositionRaw = (dict["disposition"] as? Int) ?? 0
        let generation = (dict["generation"] as? Int) ?? 0
        let bundleID = (resolvedObject(for: "bundleIdentifier", in: dict, objects: objects) as? String) ?? ""
        let parentID = (
            (resolvedObject(for: "parentIdentifier", in: dict, objects: objects) as? String)
                ?? (resolvedObject(for: "container", in: dict, objects: objects) as? String)
                ?? ""
        )
        let url = urlText(from: resolvedObject(for: "url", in: dict, objects: objects), objects: objects)
        let uuid = uuidText(from: resolvedObject(for: "uuid", in: dict, objects: objects))
        let embedded = identifiersInItems(resolvedObject(for: "items", in: dict, objects: objects), objects: objects)

        lines.append("#\(index):")
        lines.append("             UUID: \(uuid)")
        lines.append("             Name: \(name)")
        lines.append("             Type: \(entryTypeText(typeRaw: typeRaw))")
        lines.append("      Disposition: \(dispositionText(raw: dispositionRaw))")
        lines.append("       Identifier: \(identifier)")
        lines.append("              URL: \(url)")
        lines.append("       Generation: \(generation)")
        lines.append("Bundle Identifier: \(bundleID)")
        if !parentID.isEmpty {
            lines.append(" Parent Identifier: \(parentID)")
        }
        lines.append("Embedded Item Identifiers:")
        for (embeddedIndex, embeddedIdentifier) in embedded.enumerated() {
            lines.append("#\(embeddedIndex): \(embeddedIdentifier)")
        }
        index += 1
    }

    guard !lines.isEmpty else {
        throw BTMWriteError.malformedStore
    }

    return lines.joined(separator: "\n")
}

private func fetchDumpViaPreferredSource() throws -> (dump: String, source: DumpSourceMethod) {
    let probe = probeBTMStoreAccess()
    if !probe.readAllowed {
        helperLog.error("BTM read permission probe failed; fallback to sfltool")
    }

    if let storeURL = probe.stores.first, probe.readAllowed {
        do {
            let dump = try convertBTMStoreToDump(storeURL)
            let directDiagnostics = collectDumpDiagnostics(from: dump)
            logDumpDiagnostics(directDiagnostics, label: "btm_file")
            if shouldCompareDumpSources() {
                do {
                    let sfltoolDump = try dumpBTMRaw()
                    let sfltoolDiagnostics = collectDumpDiagnostics(from: sfltoolDump)
                    logDumpDiagnostics(sfltoolDiagnostics, label: "sfltool")
                    logDumpComparison(primary: directDiagnostics, fallback: sfltoolDiagnostics)
                } catch {
                    helperLog.error("Dump comparison skipped: failed to run sfltool for diagnostics: \(error.localizedDescription, privacy: .public)")
                }
            }
            helperLog.info("Dump source=btm_file path=\(storeURL.path, privacy: .public)")
            return (dump, .btmFile)
        } catch {
            helperLog.error("Direct BTM parse failed, fallback to sfltool: \(error.localizedDescription, privacy: .public)")
        }
    } else {
        helperLog.error("No BTM store file discovered; fallback to sfltool")
    }

    let dump = try dumpBTMRaw()
    helperLog.info("Dump source=sfltool")
    return (dump, .sfltool)
}

private func removeIdentifier(_ identifier: String, from storeURL: URL) throws -> Bool {
    let data = try Data(contentsOf: storeURL)
    var format = PropertyListSerialization.PropertyListFormat.binary
    guard let root = try PropertyListSerialization.propertyList(
        from: data,
        options: [.mutableContainersAndLeaves],
        format: &format
    ) as? NSMutableDictionary else {
        throw BTMWriteError.malformedStore
    }

    guard let objects = root["$objects"] as? NSMutableArray else {
        throw BTMWriteError.malformedStore
    }

    let objectSnapshot = objects.compactMap { $0 }
    var targetUIDs = Set<Int>()

    for (index, object) in objectSnapshot.enumerated() {
        guard let dict = object as? [String: Any] else { continue }
        guard let identifierUID = uidValue(from: dict["identifier"]) else { continue }
        if stringFromObjects(objectSnapshot, uid: identifierUID) == identifier {
            targetUIDs.insert(index)
        }
    }

    guard !targetUIDs.isEmpty else {
        return false
    }

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
                let before = arrayValue.count
                let filtered = arrayValue.filter { element in
                    guard let uid = uidValue(from: element) else { return true }
                    return !targetUIDs.contains(uid)
                }
                if filtered.count != before {
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

private func reloadBackgroundTaskManagement() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = ["kickstart", "-k", "system/com.apple.backgroundtaskmanagementd"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        helperLog.info("kickstart backgroundtaskmanagementd exit=\(process.terminationStatus)")
    } catch {
        helperLog.error("Failed to kickstart backgroundtaskmanagementd: \(error.localizedDescription, privacy: .public)")
    }
}

private func performSingleDelete(identifier: String) throws {
    let stores = discoverBTMStoreFiles()
    guard !stores.isEmpty else {
        throw BTMWriteError.noStoreFiles
    }

    var deletedFromAnyStore = false
    for store in stores {
        let deleted = try removeIdentifier(identifier, from: store)
        deletedFromAnyStore = deletedFromAnyStore || deleted
    }

    guard deletedFromAnyStore else {
        throw BTMWriteError.targetNotFound(identifier)
    }

    reloadBackgroundTaskManagement()
}

private func fetchBTMDump(_ request: HelperDumpRequest) -> HelperDumpResponse {
    helperLog.info("Received dump request, version=\(request.version)")
    guard request.version == helperProtocolVersion else {
        helperLog.error("Protocol mismatch: expected=\(helperProtocolVersion) actual=\(request.version)")
        return HelperDumpResponse(
            version: helperProtocolVersion,
            dump: "",
            sourceMethodRawValue: DumpSourceMethod.sfltool.rawValue,
            errorCode: "protocol_mismatch",
            errorMessage: "protocol_mismatch"
        )
    }

    do {
        let result = try fetchDumpViaPreferredSource()
        helperLog.info("Dump completed, bytes=\(result.dump.utf8.count)")
        return HelperDumpResponse(
            version: helperProtocolVersion,
            dump: result.dump,
            sourceMethodRawValue: result.source.rawValue,
            errorCode: nil,
            errorMessage: nil
        )
    } catch {
        helperLog.error("Dump execution failed: \(error.localizedDescription, privacy: .public)")
        return HelperDumpResponse(
            version: helperProtocolVersion,
            dump: "",
            sourceMethodRawValue: DumpSourceMethod.sfltool.rawValue,
            errorCode: "execution_failed",
            errorMessage: error.localizedDescription
        )
    }
}

private func fetchCapabilities(_ request: HelperCapabilitiesRequest) -> HelperCapabilitiesResponse {
    helperLog.info("Received capabilities request, version=\(request.version)")
    guard request.version == helperCapabilitiesRouteVersion else {
        helperLog.error("Capabilities route mismatch: expected=\(helperCapabilitiesRouteVersion) actual=\(request.version)")
        return HelperCapabilitiesResponse(
            version: helperCapabilitiesRouteVersion,
            helperVersion: currentHelperVersion(),
            interfaceVersion: helperInterfaceVersion,
            supportsWriteOperations: false,
            writeSchemaVersion: 0,
            errorCode: "route_version_mismatch",
            errorMessage: "route_version_mismatch"
        )
    }

    return HelperCapabilitiesResponse(
        version: helperCapabilitiesRouteVersion,
        helperVersion: currentHelperVersion(),
        interfaceVersion: helperInterfaceVersion,
        supportsWriteOperations: supportsWriteOperations(),
        writeSchemaVersion: supportsWriteOperations() ? 1 : 0,
        errorCode: nil,
        errorMessage: nil
    )
}

private func performWrite(_ request: HelperWriteRequest) -> HelperWriteResponse {
    helperLog.info("Received write request op=\(request.operation.rawValue, privacy: .public) identifier=\(request.identifier, privacy: .public)")
    guard request.version == helperWriteRouteVersion else {
        helperLog.error("Write route mismatch: expected=\(helperWriteRouteVersion) actual=\(request.version)")
        return HelperWriteResponse(
            version: helperWriteRouteVersion,
            errorCode: "route_version_mismatch",
            errorMessage: "route_version_mismatch"
        )
    }

    let identifier = request.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !identifier.isEmpty else {
        helperLog.error("Write request rejected: empty identifier")
        return HelperWriteResponse(
            version: helperWriteRouteVersion,
            errorCode: "invalid_request",
            errorMessage: "invalid_request: empty identifier"
        )
    }

    switch request.operation {
    case .toggle:
        guard request.enabled != nil else {
            helperLog.error("Toggle request rejected: missing enabled flag")
            return HelperWriteResponse(
                version: helperWriteRouteVersion,
                errorCode: "invalid_request",
                errorMessage: "invalid_request: missing enabled"
            )
        }
    case .delete:
        guard request.modeRawValue != nil else {
            helperLog.error("Delete request rejected: missing mode")
            return HelperWriteResponse(
                version: helperWriteRouteVersion,
                errorCode: "invalid_request",
                errorMessage: "invalid_request: missing mode"
            )
        }
    }

    guard supportsWriteOperations() else {
        helperLog.error("Write request blocked: write operations not supported on current system")
        return HelperWriteResponse(
            version: helperWriteRouteVersion,
            errorCode: "write_not_supported",
            errorMessage: "write_not_supported"
        )
    }
    do {
        switch request.operation {
        case .delete:
            try performSingleDelete(identifier: identifier)
        case .toggle:
            return HelperWriteResponse(
                version: helperWriteRouteVersion,
                errorCode: "write_not_supported",
                errorMessage: "toggle_not_supported_yet"
            )
        }
        return HelperWriteResponse(version: helperWriteRouteVersion, errorCode: nil, errorMessage: nil)
    } catch {
        helperLog.error("Write execution failed: \(error.localizedDescription, privacy: .public)")
        return HelperWriteResponse(
            version: helperWriteRouteVersion,
            errorCode: "execution_failed",
            errorMessage: error.localizedDescription
        )
    }
}

private func scheduleSelfUninstall() {
    DispatchQueue.global(qos: .utility).async {
        usleep(80 * 1000)
        do {
            try performSelfUninstallImmediately()
        } catch {
            helperLog.error("Deferred self-uninstall failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private func performSelfUninstallImmediately() throws -> Never {
    let helperPath = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperBundleIdentifier)")
    let launchDaemonPath = URL(fileURLWithPath: "/Library/LaunchDaemons/\(helperBundleIdentifier).plist")
    let currentExecutable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()

    guard currentExecutable.path == helperPath.path else {
        throw NSError(
            domain: helperBundleIdentifier,
            code: 11,
            userInfo: [NSLocalizedDescriptionKey: "uninstall_not_running_from_blessed_location"]
        )
    }

    if FileManager.default.fileExists(atPath: launchDaemonPath.path) {
        try FileManager.default.removeItem(at: launchDaemonPath)
        helperLog.info("Removed launch daemon plist at \(launchDaemonPath.path, privacy: .public)")
    }

    if FileManager.default.fileExists(atPath: helperPath.path) {
        try FileManager.default.removeItem(at: helperPath)
        helperLog.info("Removed helper binary at \(helperPath.path, privacy: .public)")
    }

    helperLog.info("Self-uninstall completed; exiting helper process")
    exit(0)
}

private func performSelfUninstall(_ request: HelperUninstallRequest) -> HelperUninstallResponse {
    helperLog.info("Received self-uninstall request")
    guard request.version == helperUninstallRouteVersion else {
        return HelperUninstallResponse(
            version: helperUninstallRouteVersion,
            errorCode: "route_version_mismatch",
            errorMessage: "route_version_mismatch"
        )
    }

    scheduleSelfUninstall()
    return HelperUninstallResponse(version: helperUninstallRouteVersion, errorCode: nil, errorMessage: nil)
}

private func currentHelperVersion() -> String {
    let info = Bundle.main.infoDictionary
    if let short = info?["CFBundleShortVersionString"] as? String, !short.isEmpty {
        return short
    }
    if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
        return build
    }
    return "0"
}

private func dumpBTMRaw() throws -> String {
    helperLog.info("Launching /usr/bin/sfltool dumpbtm")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sfltool")
    process.arguments = ["dumpbtm"]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    helperLog.info("sfltool exited with status=\(process.terminationStatus), rawBytes=\(data.count)")
    guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
        throw NSError(domain: helperBundleIdentifier, code: 1)
    }
    guard process.terminationStatus == 0 else {
        throw NSError(domain: helperBundleIdentifier, code: Int(process.terminationStatus))
    }
    return raw
}

do {
    let server = try XPCServer.forMachService()
    server.registerRoute(helperDumpRoute, handler: fetchBTMDump)
    server.registerRoute(helperCapabilitiesRoute, handler: fetchCapabilities)
    server.registerRoute(helperWriteRoute, handler: performWrite)
    server.registerRoute(helperUninstallRoute, handler: performSelfUninstall)
    server.setErrorHandler { _ in }
    helperLog.info("Helper server started")
    server.startAndBlock()
} catch {
    helperLog.error("Helper server failed to start: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
