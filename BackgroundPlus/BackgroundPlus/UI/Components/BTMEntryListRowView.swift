import SwiftUI

struct BTMEntryListRowView: View {
    let entry: BTMEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name.isEmpty ? entry.identifier : entry.name)
                .font(.headline)
            Text(entry.identifier)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
