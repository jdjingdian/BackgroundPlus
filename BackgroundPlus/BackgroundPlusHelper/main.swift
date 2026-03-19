import Foundation
import SecureXPC
import os

private let helperBundleIdentifier = "cn.magicdian.BackgroundPlus.helper"
private let helperProtocolVersion = 1
private let helperCapabilitiesRouteVersion = 1
private let helperInterfaceVersion = 1
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

private struct HelperCapabilitiesRequest: Codable {
    let version: Int
}

private struct HelperCapabilitiesResponse: Codable {
    let version: Int
    let helperVersion: String
    let interfaceVersion: Int
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

private func fetchCapabilities(_ request: HelperCapabilitiesRequest) -> HelperCapabilitiesResponse {
    helperLog.info("Received capabilities request, version=\(request.version)")
    guard request.version == helperCapabilitiesRouteVersion else {
        helperLog.error("Capabilities route mismatch: expected=\(helperCapabilitiesRouteVersion) actual=\(request.version)")
        return HelperCapabilitiesResponse(
            version: helperCapabilitiesRouteVersion,
            helperVersion: currentHelperVersion(),
            interfaceVersion: helperInterfaceVersion,
            errorCode: "route_version_mismatch",
            errorMessage: "route_version_mismatch"
        )
    }

    return HelperCapabilitiesResponse(
        version: helperCapabilitiesRouteVersion,
        helperVersion: currentHelperVersion(),
        interfaceVersion: helperInterfaceVersion,
        errorCode: nil,
        errorMessage: nil
    )
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
    server.setErrorHandler { _ in }
    helperLog.info("Helper server started")
    server.startAndBlock()
} catch {
    helperLog.error("Helper server failed to start: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
