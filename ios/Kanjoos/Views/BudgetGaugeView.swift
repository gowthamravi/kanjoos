import SwiftUI

struct BudgetGaugeView: View {
    let status: BudgetStatus?

    private var stateColor: Color {
        switch status?.state {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private var stateLabel: String {
        switch status?.state {
        case "green": return "All good"
        case "yellow": return "Watch it"
        case "red": return "Month-end mode"
        default: return "—"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(stateLabel, systemImage: "fuelpump.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stateColor)
                Spacer()
                if let s = status {
                    Text("₹\(Int(s.remaining)) left · \(s.daysLeft)d")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if s.simDateActive {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Simulated date active")
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(stateColor.gradient)
                        .frame(width: geo.size.width * (status?.fractionRemaining ?? 0))
                        .animation(.spring(duration: 0.6), value: status?.remaining)
                }
            }
            .frame(height: 10)
            if let s = status {
                HStack {
                    Text("Safe to spend: ₹\(Int(s.safeDailySpend))/day")
                    Spacer()
                    Text("Spent ₹\(Int(s.spent)) of ₹\(Int(s.monthlyBudget))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
