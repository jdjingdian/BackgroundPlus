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

            if !viewModel.helperErrorMessage.isEmpty {
                Text(viewModel.helperErrorMessage)
                    .foregroundStyle(.red)
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
