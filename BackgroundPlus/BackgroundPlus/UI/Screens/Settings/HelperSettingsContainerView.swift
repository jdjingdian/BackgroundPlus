import SwiftUI
import AppKit
import Combine

struct HelperSettingsContainerView: View {
    @ObservedObject var viewModel: BTMViewModel
    @State private var showUninstallConfirmAlert = false
    private let settingsWidth: CGFloat = 560
    private let iconLength: CGFloat = 128
    private let permissionRefreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            generalTabContent
                .tabItem {
                    Label(localized("btm.settings.nav.general"), systemImage: "gear")
                }

            permissionTabContent
                .tabItem {
                    Label(localized("btm.settings.nav.permissions"), systemImage: "lock.shield")
                }

            aboutTabContent
                .tabItem {
                    Label(localized("btm.settings.nav.about"), systemImage: "questionmark.circle")
                }
        }
        .frame(width: settingsWidth)
        .padding(.top, 4)
        .alert(localized("btm.settings.uninstall.confirm.title"), isPresented: $showUninstallConfirmAlert) {
            Button(localized("btm.settings.uninstall.confirm.action"), role: .destructive) {
                viewModel.uninstallHelper()
            }
            Button(localized("btm.settings.uninstall.confirm.cancel"), role: .cancel) {}
        } message: {
            Text(localized("btm.settings.uninstall.confirm.message"))
        }
        .onAppear {
            viewModel.refreshHelperStatusAndCapabilities(forceRefresh: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshHelperStatusAndCapabilities(forceRefresh: true)
        }
        .onReceive(permissionRefreshTimer) { _ in
            viewModel.refreshHelperStatusAndCapabilities(forceRefresh: true)
        }
    }

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localized("btm.settings.helper_status"))
                    .font(.title3.bold())
                statusBadge
                Spacer()
                primaryActionButton
            }

            Text(generalStateFooter)
                .font(.footnote.italic())
                .foregroundStyle(.secondary)

            if viewModel.helperState == .installed {
                Text(localized("btm.settings.state.method.smjobbless"))
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
            }

            if viewModel.helperCompatibilityState.requiresReinstall {
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized(viewModel.compatibilityWarningTitleKey), systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(viewModel.compatibilityWarningBody)
                        .foregroundStyle(.primary)
                    Button(localized("btm.settings.reinstall_now")) {
                        viewModel.installHelper()
                        viewModel.load()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !viewModel.helperErrorMessage.isEmpty {
                Text(viewModel.helperErrorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 2)
            }

            Divider()

            HStack(spacing: 10) {
                Button(localized("btm.settings.refresh_status")) {
                    viewModel.refreshHelperStatusAndCapabilities(forceRefresh: true)
                }
                .buttonStyle(.bordered)

                Spacer()

                if viewModel.helperState == .installed {
                    Button(localized("btm.settings.uninstall"), role: .destructive) {
                        showUninstallConfirmAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isUninstallingHelper)
                }
            }

            if viewModel.isUninstallingHelper {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localized("btm.settings.uninstall.in_progress"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private var permissionTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("btm.settings.permission.title"))
                    .font(.title3.bold())
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: fdaStatusIconName)
                    .foregroundStyle(fdaStatusColor)
                Text(localized(viewModel.fdaPermissionStatusKey))
                    .font(.headline)
            }

            Text(localized("btm.settings.permission.fda.description"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.fdaPermissionState == .disabled || viewModel.fdaPermissionState == .detectionFailed {
                Button(localized("btm.settings.permission.fda.open_settings")) {
                    openFullDiskAccessSettings()
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.fdaPermissionState == .enabled {
                Label(localized("btm.settings.permission.fda.ok"), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var aboutTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                appIconView

                VStack(alignment: .leading, spacing: 8) {
                    Text(appName)
                        .font(.largeTitle.bold())
                    Text(localized("btm.settings.about.subtitle"))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 2)

                    Text(String(format: localized("btm.settings.about.version"), appVersion))
                        .font(.caption.italic())
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: localized("btm.settings.managed_by"), "SMJobBless"))
                        .font(.footnote)
                Text(localized("btm.settings.about.license"))
                        .font(.footnote)
                    Text(copyrightText)
                        .font(.footnote)
                }
                Spacer()
                Button {
                    openProjectHomepage()
                } label: {
                    Label(localized("btm.settings.about.homepage"), systemImage: "house")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private var appIconView: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: iconLength, height: iconLength)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch viewModel.helperState {
        case .notInstalled:
            Button(localized("btm.settings.install")) {
                viewModel.installHelper()
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        case .failed:
            Button(localized("btm.settings.retry")) {
                viewModel.installHelper()
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        case .installing:
            Button(localized("btm.settings.state.installing")) {}
                .buttonStyle(.bordered)
                .disabled(true)
        case .installed:
            Button(localized("btm.settings.reinstall_now")) {
                viewModel.installHelper()
                viewModel.load()
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusBadge: some View {
        let (icon, tint): (String, Color) = {
            switch viewModel.helperState {
            case .installed:
                return ("checkmark.circle.fill", .green)
            case .installing:
                return ("clock.fill", .orange)
            case .failed:
                return ("xmark.octagon.fill", .red)
            case .notInstalled:
                return ("minus.circle.fill", .gray)
            }
        }()

        return Image(systemName: icon)
            .font(.body)
            .foregroundStyle(tint)
    }

    private var generalStateFooter: String {
        let state = localized(statusStateKey)
        let compatibility = localized(viewModel.compatibilityStatusKey)
        let compatibilityLabel = localized("btm.settings.compatibility_status")
        return "\(state) · \(compatibilityLabel): \(compatibility)"
    }

    private var statusStateKey: String {
        switch viewModel.helperState {
        case .notInstalled:
            return "btm.settings.state.not_installed"
        case .installing:
            return "btm.settings.state.installing"
        case .installed:
            return "btm.settings.state.installed"
        case .failed:
            return "btm.settings.state.failed"
        }
    }

    private var appName: String {
        if let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !display.isEmpty {
            return display
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        return "BackgroundPlus"
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    private var copyrightText: String {
        let year = Calendar.current.component(.year, from: .now)
        return String(format: localized("btm.settings.about.copyright"), year)
    }

    private var fdaStatusIconName: String {
        switch viewModel.fdaPermissionState {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "exclamationmark.triangle.fill"
        case .detectionFailed:
            return "xmark.octagon.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var fdaStatusColor: Color {
        switch viewModel.fdaPermissionState {
        case .enabled:
            return .green
        case .disabled:
            return .orange
        case .detectionFailed:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func openProjectHomepage() {
        guard let url = URL(string: "https://github.com/jdjingdian/BackgroundPlus") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openFullDiskAccessSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]

        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            _ = NSWorkspace.shared.open(fallback)
        }
    }

}
