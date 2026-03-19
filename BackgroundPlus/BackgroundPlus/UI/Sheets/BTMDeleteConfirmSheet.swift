import SwiftUI

struct BTMDeleteConfirmSheet: View {
    let entry: BTMEntry
    let plan: DeletePlan
    let risk: RiskLevel
    let confirmation: ConfirmationLevel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var challenge = ""
    @State private var enableAt = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titleKey)
                .font(.title3.bold())
                .accessibilityIdentifier(titleKey)

            Text(String(format: localized("btm.confirm.dry_run.summary"), plan.dryRunSummary.totalPlanned, typeBreakdown))

            List(plan.plannedEntries) { item in
                HStack {
                    Text(item.identifier)
                    Spacer()
                    if item.required {
                        Text("btm.delete.required")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 120)

            if confirmation == .textChallenge {
                TextField(localized("btm.confirm.challenge.placeholder"), text: $challenge)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(localized("btm.confirm.button.cancel")) {
                    onCancel()
                }
                Spacer()
                Button(localized("btm.confirm.button.delete"), role: .destructive) {
                    onConfirm()
                }
                .disabled(!canConfirm)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 400)
        .onAppear {
            enableAt = Date().addingTimeInterval(3)
        }
    }

    private var canConfirm: Bool {
        if confirmation == .textChallenge {
            let suffix = entry.identifier.split(separator: ".").last.map(String.init) ?? entry.identifier
            return challenge == suffix && Date() >= enableAt
        }
        return true
    }

    private var titleKey: String {
        switch risk {
        case .low:
            "btm.confirm.title.low"
        case .medium:
            "btm.confirm.title.medium"
        case .high:
            "btm.confirm.title.high"
        }
    }

    private var typeBreakdown: String {
        let pairs = plan.dryRunSummary.byType.sorted { $0.key.rawValue < $1.key.rawValue }
        return pairs.map { "\($0.value) \($0.key.rawValue)" }.joined(separator: ", ")
    }
}
