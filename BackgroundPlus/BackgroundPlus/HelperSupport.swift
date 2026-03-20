import Foundation
import Blessed
import SecureXPC
import os

let helperBundleIdentifier = "cn.magicdian.BackgroundPlus.helper"
let helperProtocolVersion = 1
let helperCapabilitiesRouteVersion = 1
let helperWriteRouteVersion = 1
private let helperClientLog = Logger(subsystem: "cn.magicdian.BackgroundPlus", category: "HelperClient")

enum HelperInstallState: String, Codable {
    case notInstalled
    case installing
    case installed
    case failed
}

enum HelperInstallError: LocalizedError, Equatable {
    case authorizationDenied
    case signingMismatch
    case blessFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "btm.helper.error.authorization_denied"
        case .signingMismatch:
            return "btm.helper.error.signing_mismatch"
        case let .blessFailed(message):
            return message.isEmpty ? "btm.helper.error.install_failed" : message
        case .unknown:
            return "btm.helper.error.install_failed"
        }
    }
}

struct HelperDumpRequest: Codable {
    let version: Int
}

struct HelperCapabilitiesRequest: Codable {
    let version: Int
}

struct HelperDumpResponse: Codable {
    let version: Int
    let dump: String
    let sourceMethodRawValue: String?
    let errorCode: String?
    let errorMessage: String?
}

struct HelperCapabilitiesResponse: Codable {
    let version: Int
    let helperVersion: String
    let interfaceVersion: Int
    let supportsWriteOperations: Bool
    let writeSchemaVersion: Int
    let errorCode: String?
    let errorMessage: String?
}

struct HelperCapabilities: Equatable {
    let helperVersion: String
    let interfaceVersion: Int
    let supportsWriteOperations: Bool
    let writeSchemaVersion: Int

    init(
        helperVersion: String,
        interfaceVersion: Int,
        supportsWriteOperations: Bool = false,
        writeSchemaVersion: Int = 0
    ) {
        self.helperVersion = helperVersion
        self.interfaceVersion = interfaceVersion
        self.supportsWriteOperations = supportsWriteOperations
        self.writeSchemaVersion = writeSchemaVersion
    }
}

enum HelperWriteOperation: String, Codable {
    case toggle
    case delete
}

struct HelperWriteRequest: Codable {
    let version: Int
    let operation: HelperWriteOperation
    let identifier: String
    let modeRawValue: String?
    let enabled: Bool?
}

struct HelperWriteResponse: Codable {
    let version: Int
    let errorCode: String?
    let errorMessage: String?
}

enum HelperCompatibilityIssue: Equatable {
    case versionMismatch(expectedAppVersion: String, actualHelperVersion: String)
    case interfaceMismatch(expectedInterfaceVersion: Int, actualInterfaceVersion: Int)
    case capabilityReadFailed
}

enum HelperValidationResult: Equatable {
    case compatible(HelperCapabilities)
    case incompatible(HelperCompatibilityIssue)
}

let helperDumpRoute = XPCRoute
    .named("btm", "fetchDump", "v1")
    .withMessageType(HelperDumpRequest.self)
    .withReplyType(HelperDumpResponse.self)

let helperCapabilitiesRoute = XPCRoute
    .named("helper", "capabilities", "v1")
    .withMessageType(HelperCapabilitiesRequest.self)
    .withReplyType(HelperCapabilitiesResponse.self)

let helperWriteRoute = XPCRoute
    .named("btm", "write", "v1")
    .withMessageType(HelperWriteRequest.self)
    .withReplyType(HelperWriteResponse.self)

protocol PrivilegedHelperClient {
    func fetchBTMDump() throws -> DumpFetchResult
    func fetchHelperCapabilities() throws -> HelperCapabilities
    func performWrite(_ request: HelperWriteRequest) throws
}

struct XPCPrivilegedHelperClient: PrivilegedHelperClient {
    func fetchBTMDump() throws -> DumpFetchResult {
        helperClientLog.info("Starting helper dump request")
        let client = XPCClient.forMachService(named: helperBundleIdentifier)
        let request = HelperDumpRequest(version: helperProtocolVersion)

        let semaphore = DispatchSemaphore(value: 0)
        var reply: Result<HelperDumpResponse, XPCError>?
        client.sendMessage(request, to: helperDumpRoute) { response in
            reply = response
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 20) == .timedOut {
            helperClientLog.error("Helper dump request timed out")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard let reply else {
            throw BTMCoreError.helperCommunicationFailed
        }

        let decoded: HelperDumpResponse
        switch reply {
        case let .success(value):
            decoded = value
        case .failure:
            helperClientLog.error("Helper dump request failed at transport layer")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard decoded.version == helperProtocolVersion else {
            helperClientLog.error("Helper protocol mismatch: expected=\(helperProtocolVersion) actual=\(decoded.version)")
            throw BTMCoreError.helperProtocolMismatch
        }
        if let code = decoded.errorCode {
            helperClientLog.error("Helper returned error: code=\(code, privacy: .public) message=\(decoded.errorMessage ?? "", privacy: .public)")
            if code == "permission_denied" {
                throw BTMCoreError.permissionDenied
            }
            throw BTMCoreError.helperExecutionFailed(decoded.errorMessage ?? code)
        }
        let sourceMethod = BTMListSourceMethod(rawValue: decoded.sourceMethodRawValue ?? "") ?? .unknown
        helperClientLog.info("Helper dump request succeeded, bytes=\(decoded.dump.utf8.count) source=\(sourceMethod.rawValue, privacy: .public)")
        return DumpFetchResult(dump: decoded.dump, sourceMethod: sourceMethod)
    }

    func fetchHelperCapabilities() throws -> HelperCapabilities {
        helperClientLog.info("Starting helper capabilities request")
        let client = XPCClient.forMachService(named: helperBundleIdentifier)
        let request = HelperCapabilitiesRequest(version: helperCapabilitiesRouteVersion)

        let semaphore = DispatchSemaphore(value: 0)
        var reply: Result<HelperCapabilitiesResponse, XPCError>?
        client.sendMessage(request, to: helperCapabilitiesRoute) { response in
            reply = response
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 20) == .timedOut {
            helperClientLog.error("Helper capabilities request timed out")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard let reply else {
            throw BTMCoreError.helperCommunicationFailed
        }

        let decoded: HelperCapabilitiesResponse
        switch reply {
        case let .success(value):
            decoded = value
        case .failure:
            helperClientLog.error("Helper capabilities request failed at transport layer")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard decoded.version == helperCapabilitiesRouteVersion else {
            helperClientLog.error("Helper capabilities route mismatch: expected=\(helperCapabilitiesRouteVersion) actual=\(decoded.version)")
            throw BTMCoreError.helperCapabilitiesUnavailable
        }

        if let code = decoded.errorCode {
            helperClientLog.error("Helper capabilities returned error: code=\(code, privacy: .public) message=\(decoded.errorMessage ?? "", privacy: .public)")
            throw BTMCoreError.helperCapabilitiesUnavailable
        }

        let capabilities = HelperCapabilities(
            helperVersion: decoded.helperVersion,
            interfaceVersion: decoded.interfaceVersion,
            supportsWriteOperations: decoded.supportsWriteOperations,
            writeSchemaVersion: decoded.writeSchemaVersion
        )
        helperClientLog.info("Helper capabilities request succeeded, helperVersion=\(capabilities.helperVersion, privacy: .public) interfaceVersion=\(capabilities.interfaceVersion)")
        return capabilities
    }

    func performWrite(_ request: HelperWriteRequest) throws {
        helperClientLog.info("Starting helper write request op=\(request.operation.rawValue, privacy: .public)")
        let client = XPCClient.forMachService(named: helperBundleIdentifier)
        let requestPayload = HelperWriteRequest(
            version: helperWriteRouteVersion,
            operation: request.operation,
            identifier: request.identifier,
            modeRawValue: request.modeRawValue,
            enabled: request.enabled
        )

        let semaphore = DispatchSemaphore(value: 0)
        var reply: Result<HelperWriteResponse, XPCError>?
        client.sendMessage(requestPayload, to: helperWriteRoute) { response in
            reply = response
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 20) == .timedOut {
            helperClientLog.error("Helper write request timed out")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard let reply else {
            throw BTMCoreError.helperCommunicationFailed
        }

        let decoded: HelperWriteResponse
        switch reply {
        case let .success(value):
            decoded = value
        case .failure:
            helperClientLog.error("Helper write request failed at transport layer")
            throw BTMCoreError.helperCommunicationFailed
        }

        guard decoded.version == helperWriteRouteVersion else {
            helperClientLog.error("Helper write route mismatch: expected=\(helperWriteRouteVersion) actual=\(decoded.version)")
            throw BTMCoreError.helperProtocolMismatch
        }

        if let code = decoded.errorCode {
            helperClientLog.error("Helper write returned error: code=\(code, privacy: .public) message=\(decoded.errorMessage ?? "", privacy: .public)")
            if code == "permission_denied" {
                throw BTMCoreError.permissionDenied
            }
            if code == "write_not_supported" {
                throw BTMCoreError.helperWriteUnsupported
            }
            throw BTMCoreError.helperExecutionFailed(decoded.errorMessage ?? code)
        }
    }
}

final class HelperCompatibilityValidator {
    private let helperClient: PrivilegedHelperClient
    private let appVersionProvider: () -> String
    private let expectedInterfaceVersion: Int
    private var cachedResult: HelperValidationResult?

    init(
        helperClient: PrivilegedHelperClient,
        expectedInterfaceVersion: Int = helperCapabilitiesRouteVersion,
        appVersionProvider: @escaping () -> String = HelperCompatibilityValidator.defaultAppVersion
    ) {
        self.helperClient = helperClient
        self.expectedInterfaceVersion = expectedInterfaceVersion
        self.appVersionProvider = appVersionProvider
    }

    func invalidate() {
        cachedResult = nil
    }

    func validate(forceRefresh: Bool = false) -> HelperValidationResult {
        if !forceRefresh, let cachedResult {
            return cachedResult
        }

        let appVersion = appVersionProvider()
        let result: HelperValidationResult

        do {
            let capabilities = try helperClient.fetchHelperCapabilities()
            if capabilities.interfaceVersion != expectedInterfaceVersion {
                result = .incompatible(
                    .interfaceMismatch(
                        expectedInterfaceVersion: expectedInterfaceVersion,
                        actualInterfaceVersion: capabilities.interfaceVersion
                    )
                )
                helperClientLog.error("Helper interface mismatch: expected=\(self.expectedInterfaceVersion) actual=\(capabilities.interfaceVersion)")
            } else if capabilities.helperVersion != appVersion {
                result = .incompatible(
                    .versionMismatch(
                        expectedAppVersion: appVersion,
                        actualHelperVersion: capabilities.helperVersion
                    )
                )
                helperClientLog.error("Helper version mismatch: expectedAppVersion=\(appVersion, privacy: .public) actualHelperVersion=\(capabilities.helperVersion, privacy: .public)")
            } else {
                result = .compatible(capabilities)
                helperClientLog.info("Helper compatibility check passed for appVersion=\(appVersion, privacy: .public)")
            }
        } catch {
            result = .incompatible(.capabilityReadFailed)
            helperClientLog.error("Helper compatibility check failed: \(error.localizedDescription, privacy: .public)")
        }

        cachedResult = result
        return result
    }

    nonisolated private static func defaultAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        if let short = info?["CFBundleShortVersionString"] as? String, !short.isEmpty {
            return short
        }
        if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
            return build
        }
        return "0"
    }
}

final class HelperInstallManager {
    private let defaults = UserDefaults.standard
    private let stateKey = "btm.helper.install.state"

    func persistedState() -> HelperInstallState {
        guard let raw = defaults.string(forKey: stateKey),
              let state = HelperInstallState(rawValue: raw) else {
            return fileSystemState()
        }
        if state == .installed {
            return fileSystemState()
        }
        return state
    }

    func refreshState() -> HelperInstallState {
        let state = fileSystemState()
        defaults.set(state.rawValue, forKey: stateKey)
        return state
    }

    func install() throws -> HelperInstallState {
        defaults.set(HelperInstallState.installing.rawValue, forKey: stateKey)

        do {
            try Blessed.PrivilegedHelperManager.shared.authorizeAndBless(
                message: "Install BackgroundPlus Helper",
                icon: nil
            )
            defaults.set(HelperInstallState.installed.rawValue, forKey: stateKey)
            return .installed
        } catch {
            defaults.set(HelperInstallState.failed.rawValue, forKey: stateKey)
            let message = String(describing: error)
            if message.localizedCaseInsensitiveContains("canceled") || message.localizedCaseInsensitiveContains("cancelled") {
                throw HelperInstallError.authorizationDenied
            }
            if message.localizedCaseInsensitiveContains("code signature") || message.localizedCaseInsensitiveContains("requirement") {
                throw HelperInstallError.signingMismatch
            }
            if message.isEmpty {
                throw HelperInstallError.unknown("unknown")
            }
            throw HelperInstallError.blessFailed(message)
        }
    }

    private func fileSystemState() -> HelperInstallState {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-test-force-no-helper") {
            return .notInstalled
        }
        if args.contains("--ui-test-force-helper-installed") {
            return .installed
        }
        let helperPath = "/Library/PrivilegedHelperTools/\(helperBundleIdentifier)"
        return FileManager.default.fileExists(atPath: helperPath) ? .installed : .notInstalled
    }
}
