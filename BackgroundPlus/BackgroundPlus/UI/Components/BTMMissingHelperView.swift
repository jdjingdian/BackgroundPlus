import SwiftUI

struct BTMMissingHelperView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("btm.helper.required.title")
                .font(.title3.bold())
            Text("btm.helper.required.body")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(localized("btm.helper.required.open_settings")) {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
