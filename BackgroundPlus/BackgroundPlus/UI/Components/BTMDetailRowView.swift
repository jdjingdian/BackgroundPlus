import SwiftUI

struct BTMDetailRowView: View {
    let titleKey: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localized(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
        }
    }
}
