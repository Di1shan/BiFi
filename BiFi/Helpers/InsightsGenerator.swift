import Foundation

// MARK: - Insights Generator
struct InsightsGenerator {
    
    struct Insight: Identifiable {
        let id = UUID()
        let type: InsightType
        let title: String
        let description: String
        let icon: String
        let color: String
        let priority: Int // 1 = high, 2 = medium, 3 = low
    }
    
    enum InsightType {
        case warning
        case tip
        case achievement
        case info
    }
    
    /// Generate insights based on transaction data
    static func generateInsights(
        transactions: [Transaction],
        categories: [Category],
        budgets: [BudgetMonth],
        monthKey: String,
        periodStart: Date,
        periodEndExclusive: Date,
        startDay: Int,
        primaryCode: String,
        secondaryCode: String
    ) -> [Insight] {
        var insights: [Insight] = []
        
        // Get current month data
        let primaryIncome = BalanceCalculator.periodIncome(transactions: transactions, currency: .primary, start: periodStart, endExclusive: periodEndExclusive)
        let primaryExpense = BalanceCalculator.periodExpense(transactions: transactions, currency: .primary, start: periodStart, endExclusive: periodEndExclusive)
        let secondaryIncome = BalanceCalculator.periodIncome(transactions: transactions, currency: .secondary, start: periodStart, endExclusive: periodEndExclusive)
        let secondaryExpense = BalanceCalculator.periodExpense(transactions: transactions, currency: .secondary, start: periodStart, endExclusive: periodEndExclusive)
        
        // Get previous month data for comparison
        let prevDate = FinancialMonthHelper.shiftFinancialAnchor(periodStart, by: -1, startDay: startDay)
        let prevPeriod = FinancialMonthHelper.financialPeriod(containing: prevDate, startDay: startDay)
        
        let prevPrimaryExpense = BalanceCalculator.periodExpense(transactions: transactions, currency: .primary, start: prevPeriod.start, endExclusive: prevPeriod.endExclusive)
        
        // Current budget
        let currentBudget = budgets.first { $0.monthKey == monthKey }
        
        // 1. Budget exceeded warning
        if let budget = currentBudget {
            if budget.primaryMonthlyBudget > 0 && primaryExpense > budget.primaryMonthlyBudget {
                let exceeded = primaryExpense - budget.primaryMonthlyBudget
                insights.append(Insight(
                    type: .warning,
                    title: "Budget Exceeded!",
                    description: "You've exceeded your \(primaryCode) budget by \(MoneyFormatter.format(exceeded, currencyCode: primaryCode)). Consider cutting back on non-essential spending.",
                    icon: "exclamationmark.triangle.fill",
                    color: "#FF6B6B",
                    priority: 1
                ))
            }
            
            if budget.secondaryMonthlyBudget > 0 && secondaryExpense > budget.secondaryMonthlyBudget {
                let exceeded = secondaryExpense - budget.secondaryMonthlyBudget
                insights.append(Insight(
                    type: .warning,
                    title: "Budget Exceeded!",
                    description: "You've exceeded your \(secondaryCode) budget by \(MoneyFormatter.format(exceeded, currencyCode: secondaryCode)).",
                    icon: "exclamationmark.triangle.fill",
                    color: "#FF6B6B",
                    priority: 1
                ))
            }
            
            // Budget almost reached (80%+)
            if budget.primaryMonthlyBudget > 0 {
                let ratio = primaryExpense / budget.primaryMonthlyBudget
                if ratio >= 0.8 && ratio < 1.0 {
                    let remaining = budget.primaryMonthlyBudget - primaryExpense
                    insights.append(Insight(
                        type: .warning,
                        title: "Approaching Budget Limit",
                        description: "You've used \(Int(ratio.doubleValue * 100))% of your \(primaryCode) budget. Only \(MoneyFormatter.format(remaining, currencyCode: primaryCode)) remaining.",
                        icon: "chart.line.uptrend.xyaxis",
                        color: "#FFD93D",
                        priority: 2
                    ))
                }
            }
        }
        
        // 2. Spending increase compared to last month
        if prevPrimaryExpense > 0 && primaryExpense > prevPrimaryExpense {
            let increase = ((primaryExpense - prevPrimaryExpense) / prevPrimaryExpense).doubleValue * 100
            if increase > 20 {
                insights.append(Insight(
                    type: .info,
                    title: "Spending Up \(Int(increase))%",
                    description: "Your \(primaryCode) spending is up compared to last month. Review your expenses to identify the cause.",
                    icon: "arrow.up.right",
                    color: "#FF8A80",
                    priority: 2
                ))
            }
        }
        
        // 3. Positive savings rate
        if primaryIncome > 0 {
            let savingsRate = ((primaryIncome - primaryExpense) / primaryIncome).doubleValue * 100
            if savingsRate >= 20 {
                insights.append(Insight(
                    type: .achievement,
                    title: "Great Savings! 🎉",
                    description: "You're saving \(Int(savingsRate))% of your \(primaryCode) income this month. Keep it up!",
                    icon: "star.fill",
                    color: "#98D8C8",
                    priority: 3
                ))
            } else if savingsRate < 10 && savingsRate >= 0 {
                insights.append(Insight(
                    type: .tip,
                    title: "Boost Your Savings",
                    description: "Your savings rate is only \(Int(savingsRate))%. Try the 50/30/20 rule: 50% needs, 30% wants, 20% savings.",
                    icon: "lightbulb.fill",
                    color: "#45B7D1",
                    priority: 2
                ))
            }
        }
        
        // 4. Category-specific insights
        let breakdown = BalanceCalculator.categoryBreakdown(
            transactions: transactions,
            categories: categories,
            currency: .primary,
            start: periodStart,
            endExclusive: periodEndExclusive
        )
        
        if let topCategory = breakdown.first, topCategory.percentage > 40 {
            let categoryName = topCategory.category?.name ?? "Uncategorized"
            insights.append(Insight(
                type: .info,
                title: "High \(categoryName) Spending",
                description: "\(Int(topCategory.percentage))% of your spending goes to \(categoryName). Consider if all these expenses are necessary.",
                icon: "chart.pie.fill",
                color: "#DDA0DD",
                priority: 2
            ))
        }
        
        // 5. No income recorded
        // Check if current period includes today
        let now = Date()
        let isCurrentPeriod = now >= periodStart && now < periodEndExclusive
        
        if primaryIncome == 0 && secondaryIncome == 0 && isCurrentPeriod {
            insights.append(Insight(
                type: .tip,
                title: "Record Your Income",
                description: "No income recorded this month. Add your salary or other income to track your savings accurately.",
                icon: "plus.circle.fill",
                color: "#4ECDC4",
                priority: 2
            ))
        }
        
        // 6. Spending decrease achievement
        if prevPrimaryExpense > 0 && primaryExpense < prevPrimaryExpense {
            let decrease = ((prevPrimaryExpense - primaryExpense) / prevPrimaryExpense).doubleValue * 100
            if decrease > 10 {
                insights.append(Insight(
                    type: .achievement,
                    title: "Spending Down \(Int(decrease))%! 👏",
                    description: "Great job! You've reduced spending compared to last month.",
                    icon: "arrow.down.right",
                    color: "#6BCB77",
                    priority: 3
                ))
            }
        }
        
        // 7. Daily budget remaining
        if let budget = currentBudget {
            if budget.primaryMonthlyBudget > 0 {
                let remaining = budget.primaryMonthlyBudget - primaryExpense
                if remaining > 0 {
                    let daysLeft = daysRemainingInPeriod(start: periodStart, endExclusive: periodEndExclusive)
                    if daysLeft > 0 {
                        let dailyBudget = remaining / Decimal(daysLeft)
                        insights.append(Insight(
                            type: .info,
                            title: "Daily Budget: \(MoneyFormatter.format(dailyBudget, currencyCode: primaryCode))",
                            description: "You can spend \(MoneyFormatter.format(dailyBudget, currencyCode: primaryCode)) per day for the next \(daysLeft) days to stay within budget.",
                            icon: "calendar.badge.clock",
                            color: "#64B5F6",
                            priority: 2
                        ))
                    }
                }
            }
        }
        
        // 8. Projected month-end spending
        if let budget = currentBudget, budget.primaryMonthlyBudget > 0 {
            let daysPassed = daysPassedInPeriod(start: periodStart, endExclusive: periodEndExclusive)
            let totalDays = totalDaysInPeriod(start: periodStart, endExclusive: periodEndExclusive)
            
            if daysPassed > 0 && totalDays > 0 {
                let dailyAverage = primaryExpense / Decimal(daysPassed)
                let projectedTotal = dailyAverage * Decimal(totalDays)
                
                if projectedTotal > budget.primaryMonthlyBudget {
                    let overBy = projectedTotal - budget.primaryMonthlyBudget
                    insights.append(Insight(
                        type: .warning,
                        title: "Projected Over Budget",
                        description: "At current pace, you'll exceed budget by \(MoneyFormatter.format(overBy, currencyCode: primaryCode)) by month end.",
                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                        color: "#FF7043",
                        priority: 1
                    ))
                } else if projectedTotal < budget.primaryMonthlyBudget * Decimal(0.7) {
                    let savings = budget.primaryMonthlyBudget - projectedTotal
                    insights.append(Insight(
                        type: .achievement,
                        title: "On Track to Save! 💰",
                        description: "At current pace, you'll save \(MoneyFormatter.format(savings, currencyCode: primaryCode)) this month!",
                        icon: "arrow.down.right.circle.fill",
                        color: "#4CAF50",
                        priority: 3
                    ))
                }
            }
        }
        
        // 9. Budget pace indicator
        if let budget = currentBudget, budget.primaryMonthlyBudget > 0 {
            let daysPassed = daysPassedInPeriod(start: periodStart, endExclusive: periodEndExclusive)
            let totalDays = totalDaysInPeriod(start: periodStart, endExclusive: periodEndExclusive)
            
            if daysPassed > 0 && totalDays > 0 {
                let expectedSpendRatio = Decimal(daysPassed) / Decimal(totalDays)
                let actualSpendRatio = primaryExpense / budget.primaryMonthlyBudget
                
                if actualSpendRatio < expectedSpendRatio * Decimal(0.8) && primaryExpense > 0 {
                    let percentAhead = Int((expectedSpendRatio - actualSpendRatio).doubleValue * 100)
                    insights.append(Insight(
                        type: .achievement,
                        title: "Ahead of Budget! 🎯",
                        description: "You're \(percentAhead)% ahead of your budget pace. Great discipline!",
                        icon: "hare.fill",
                        color: "#81C784",
                        priority: 3
                    ))
                }
            }
        }
        
        // 10. No budget set
        if currentBudget == nil || (currentBudget?.primaryMonthlyBudget == 0 && currentBudget?.secondaryMonthlyBudget == 0) {
            insights.append(Insight(
                type: .tip,
                title: "Set a Budget",
                description: "Setting a monthly budget helps you control spending. Go to Budgets tab to set one.",
                icon: "target",
                color: "#45B7D1",
                priority: 3
            ))
        }
        
        // Sort by priority
        return insights.sorted { $0.priority < $1.priority }
    }
    
    /// Get smart suggestions based on spending patterns
    static func generateSuggestions(
        transactions: [Transaction],
        categories: [Category],
        monthKey: String,
        periodStart: Date,
        periodEndExclusive: Date,
        primaryCode: String
    ) -> [String] {
        var suggestions: [String] = []
        
        let breakdown = BalanceCalculator.categoryBreakdown(
            transactions: transactions,
            categories: categories,
            currency: .primary,
            start: periodStart,
            endExclusive: periodEndExclusive
        )
        
        // Food spending suggestion
        if let food = breakdown.first(where: { $0.category?.name == "Food" }), food.percentage > 30 {
            suggestions.append("🍽️ Try meal prepping on weekends to reduce food expenses")
        }
        
        // Entertainment suggestion
        if let entertainment = breakdown.first(where: { $0.category?.name == "Entertainment" }), entertainment.percentage > 15 {
            suggestions.append("🎮 Look for free entertainment options like parks, libraries, or free events")
        }
        
        // Shopping suggestion
        if let shopping = breakdown.first(where: { $0.category?.name == "Shopping" }), shopping.percentage > 20 {
            suggestions.append("🛍️ Try the 24-hour rule: wait a day before non-essential purchases")
        }
        
        // Transport suggestion
        if let transport = breakdown.first(where: { $0.category?.name == "Transport" }), transport.percentage > 15 {
            suggestions.append("🚗 Consider carpooling, public transit, or biking to save on transport")
        }
        
        // General suggestions
        let totalExpense = BalanceCalculator.periodExpense(transactions: transactions, currency: .primary, start: periodStart, endExclusive: periodEndExclusive)
        let totalIncome = BalanceCalculator.periodIncome(transactions: transactions, currency: .primary, start: periodStart, endExclusive: periodEndExclusive)
        
        if totalIncome > 0 && totalExpense > totalIncome * 0.9 {
            suggestions.append("💰 Set up automatic transfers to savings on payday")
        }
        
        if suggestions.isEmpty {
            suggestions.append("✨ Great job managing your finances! Keep tracking your expenses")
            suggestions.append("📊 Review your spending weekly to stay on top of your budget")
        }
        
        return suggestions
    }
    
    // MARK: - Helpers
    
    private static func daysRemainingInPeriod(start: Date, endExclusive: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        if today >= endExclusive { return 0 } // Past
        if today < start { 
           // Future: all days
           let components = calendar.dateComponents([.day], from: start, to: endExclusive)
           return components.day ?? 30
        }
        
        // Current
        let components = calendar.dateComponents([.day], from: today, to: endExclusive)
        return max(0, components.day ?? 0)
    }
    
    private static func daysPassedInPeriod(start: Date, endExclusive: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        if today >= endExclusive {
            // Past: all days
            let components = calendar.dateComponents([.day], from: start, to: endExclusive)
            return components.day ?? 30
        }
        if today < start { return 0 } // Future
        
        // Current
        let components = calendar.dateComponents([.day], from: start, to: today)
        return max(1, (components.day ?? 0) + 1)
    }
    
    private static func totalDaysInPeriod(start: Date, endExclusive: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: endExclusive)
        return max(1, components.day ?? 30)
    }
}

