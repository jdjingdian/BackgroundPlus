import Foundation
import SecureXPC
import os

private let helperBundleIdentifier = "cn.magicdian.BackgroundPlus.helper"
private let helperProtocolVersion = 1
private let helperLog = Logger(subsystem: helperBundleIdentifier, category: "HelperServer")

private struct HelperDumpRequest: Codable {
    let version: Int
}

private struct HelperDumpResponse: Codable {
    let version: Int
    let dump: String
    let errorCode: String?
    let errorMessage: String?
}

private let helperDumpRoute = XPCRoute
    .named("btm", "fetchDump", "v1")
    .withMessageType(HelperDumpRequest.self)
    .withReplyType(HelperDumpResponse.self)

private func fetchBTMDump(_ request: HelperDumpRequest) -> HelperDumpResponse {
    helperLog.info("Received dump request, version=\(request.version)")
    guard request.version == helperProtocolVersion else {
        helperLog.error("Protocol mismatch: expected=\(helperProtocolVersion) actual=\(request.version)")
        return HelperDumpResponse(
            version: helperProtocolVersion,
            dump: "",
            errorCode: "protocol_mismatch",
            errorMessage: "protocol_mismatch"
        )
    }

    do {
        let dump = try dumpBTMRaw()
        helperLog.info("Dump completed, bytes=\(dump.utf8.count)")
        return HelperDumpResponse(version: helperProtocolVersion, dump: dump, errorCode: nil, errorMessage: nil)
    } catch {
        helperLog.error("Dump execution failed: \(error.localizedDescription, privacy: .public)")
        return HelperDumpResponse(version: helperProtocolVersion, dump: "", errorCode: "execution_failed", errorMessage: error.localizedDescription)
    }
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
    server.setErrorHandler { _ in }
    helperLog.info("Helper server started")
    server.startAndBlock()
} catch {
    helperLog.error("Helper server failed to start: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
