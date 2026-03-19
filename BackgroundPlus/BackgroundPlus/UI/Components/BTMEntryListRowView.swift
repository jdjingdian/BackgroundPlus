import SwiftUI
import AppKit

struct BTMEntryListRowView: View {
    let entry: BTMEntry
    let isEnabled: Bool
    let canOpenCustomDetail: Bool
    let onToggle: (Bool) -> Void
    let onOpenCustomDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            appIcon
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name.isEmpty ? entry.identifier : entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                )
            )
            .labelsHidden()
            .accessibilityIdentifier("btm.row.toggle")
            .accessibilityLabel(Text(toggleAccessibilityLabelText))
            .accessibilityValue(Text(toggleAccessibilityValueText))
            .toggleStyle(SwitchToggleStyle())

            Button(action: onOpenCustomDetail) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canOpenCustomDetail)
            .accessibilityLabel(Text("btm.list.open_custom_detail"))
            .accessibilityIdentifier("btm.row.custom_detail_button")
            .foregroundStyle(canOpenCustomDetail ? .secondary : .tertiary)
            .padding(.leading, 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenCustomDetail()
        }
    }

    private var appIcon: some View {
        Group {
            if let image = loadFileIcon() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackSymbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fallbackSymbolName: String {
        switch entry.type {
        case .app:
            return "app.fill"
        case .daemon:
            return "gearshape.2.fill"
        case .agent:
            return "person.crop.circle"
        case .developer:
            return "hammer.fill"
        case .unknown:
            return "questionmark.app.fill"
        }
    }

    private func loadFileIcon() -> NSImage? {
        guard let fileURL = URL(string: entry.url), fileURL.isFileURL else {
            return nil
        }
        let path = fileURL.path
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private var entryDisplayName: String {
        entry.name.isEmpty ? entry.identifier : entry.name
    }

    private var toggleAccessibilityLabelText: String {
        String(format: localized("btm.list.toggle.accessibility.label"), entryDisplayName)
    }

    private var toggleAccessibilityValueText: String {
        localized(isEnabled ? "btm.list.toggle.accessibility.value.on" : "btm.list.toggle.accessibility.value.off")
    }
}
