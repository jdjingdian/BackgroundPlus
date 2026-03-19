import SwiftUI

struct HelperSettingsContainerView: View {
    @ObservedObject var viewModel: BTMViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("btm.settings.title")
                .font(.title2.bold())

            HStack {
                Text("btm.settings.helper_status")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.headline)
            }

            HStack {
                Text("btm.settings.compatibility_status")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(localized(viewModel.compatibilityStatusKey))
                    .font(.headline)
                    .foregroundStyle(viewModel.helperCompatibilityState.requiresReinstall ? .red : .primary)
            }

            if !viewModel.helperErrorMessage.isEmpty {
                Text(viewModel.helperErrorMessage)
                    .foregroundStyle(.red)
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
                .padding(12)
                .background(.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 12) {
                Button(localized("btm.settings.install")) {
                    viewModel.installHelper()
                    viewModel.load()
                }
                .disabled(viewModel.helperState == .installing)

                Button(localized("btm.settings.retry")) {
                    viewModel.installHelper()
                    viewModel.load()
                }
                .disabled(viewModel.helperState == .installing)

                Button(localized("btm.settings.refresh_status")) {
                    viewModel.refreshHelperState()
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 280)
        .onAppear {
            viewModel.refreshHelperState()
        }
    }

    private var statusText: String {
        switch viewModel.helperState {
        case .notInstalled:
            return localized("btm.settings.state.not_installed")
        case .installing:
            return localized("btm.settings.state.installing")
        case .installed:
            return localized("btm.settings.state.installed")
        case .failed:
            return localized("btm.settings.state.failed")
        }
    }
}
