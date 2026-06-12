import Foundation

struct BudgetStatus: Decodable, Equatable {
    let date: String
    let monthlyBudget: Double
    let spent: Double
    let remaining: Double
    let daysLeft: Int
    let dailyBaseline: Double
    let safeDailySpend: Double
    let state: String
    let simDateActive: Bool

    var fractionRemaining: Double {
        guard monthlyBudget > 0 else { return 0 }
        return max(0, min(1, remaining / monthlyBudget))
    }
}
