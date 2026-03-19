import Foundation
import Blessed
import SecureXPC
import os

let helperBundleIdentifier = "cn.magicdian.BackgroundPlus.helper"
let helperProtocolVersion = 1
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

struct HelperDumpResponse: Codable {
    let version: Int
    let dump: String
    let errorCode: String?
    let errorMessage: String?
}

let helperDumpRoute = XPCRoute
    .named("btm", "fetchDump", "v1")
    .withMessageType(HelperDumpRequest.self)
    .withReplyType(HelperDumpResponse.self)

protocol PrivilegedHelperClient {
    func fetchBTMDump() throws -> String
}

struct XPCPrivilegedHelperClient: PrivilegedHelperClient {
    func fetchBTMDump() throws -> String {
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
        helperClientLog.info("Helper dump request succeeded, bytes=\(decoded.dump.utf8.count)")
        return decoded.dump
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
