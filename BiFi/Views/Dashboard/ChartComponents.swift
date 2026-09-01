import SwiftUI
import Charts

// MARK: - Spending Chart Data
struct SpendingChartData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let color: Color
    let percentage: Double
}

// MARK: - Daily Spending Data
struct DailySpendingData: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
    let dayLabel: String
}

// MARK: - Trend Data
struct TrendData: Identifiable {
    let id = UUID()
    let month: String
    let income: Decimal
    let expense: Decimal
}

// MARK: - Category Pie Chart
struct CategoryPieChart: View {
    let data: [SpendingChartData]
    let currencyCode: String
    
    @State private var selectedSlice: SpendingChartData?
    @State private var selectedAngle: Double?
    
    private var totalAmount: Decimal {
        data.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if data.isEmpty {
                emptyState
            } else {
                HStack(spacing: 20) {
                    // Pie Chart with tap interaction
                    ZStack {
                        Chart(data) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount.doubleValue),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(4)
                            .opacity(selectedSlice?.id == item.id ? 1 : 0.8)
                        }
                        .chartLegend(.hidden)
                        .chartAngleSelection(value: $selectedAngle)
                        .frame(width: 120, height: 120)
                        
                        // Center label when selected
                        if let slice = selectedSlice {
                            VStack(spacing: 2) {
                                Text(slice.category)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(MoneyFormatter.format(slice.amount, currencyCode: currencyCode))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(slice.color)
                            }
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3), value: selectedSlice?.id)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(data.prefix(5)) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                
                                Text(item.category)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(Int(item.percentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedSlice?.id == item.id {
                                        selectedSlice = nil
                                    } else {
                                        selectedSlice = item
                                    }
                                }
                            }
                            .background(selectedSlice?.id == item.id ? item.color.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: selectedAngle) { _, newValue in
            if let angle = newValue {
                withAnimation(.spring(response: 0.3)) {
                    selectedSlice = findSlice(at: angle)
                }
            }
        }
    }
    
    private func findSlice(at angle: Double) -> SpendingChartData? {
        var cumulativeAngle: Double = 0
        let total = totalAmount.doubleValue
        guard total > 0 else { return nil }
        
        for item in data {
            let sliceAngle = (item.amount.doubleValue / total) * 360
            if angle >= cumulativeAngle && angle < cumulativeAngle + sliceAngle {
                return item
            }
            cumulativeAngle += sliceAngle
        }
        return data.last
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.pie")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No expenses to display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}

// MARK: - Daily Spending Bar Chart
struct DailySpendingChart: View {
    let data: [DailySpendingData]
    let currencyCode: String
    
    @State private var selectedDay: String?
    
    private var selectedItem: DailySpendingData? {
        guard let day = selectedDay else { return nil }
        return data.first { $0.dayLabel == day }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Spending (Last 7 Days)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Selected day tooltip
                if let item = selectedItem {
                    HStack(spacing: 4) {
                        Text(item.dayLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(MoneyFormatter.format(item.amount, currencyCode: currencyCode))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: selectedDay)
            
            if data.isEmpty {
                emptyState
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("Amount", item.amount.doubleValue)
                    )
                    .foregroundStyle(
                        selectedDay == nil || selectedDay == item.dayLabel
                        ? LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                }
                .chartXSelection(value: $selectedDay)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompact(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No recent spending data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fK", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Income vs Expense Trend Chart

// Helper struct for flattened chart data
struct TrendPoint: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
    let series: String
}

struct TrendChart: View {
    let data: [TrendData]
    let currencyCode: String
    
    // Flatten data into individual points with series identifier
    private var chartPoints: [TrendPoint] {
        var points: [TrendPoint] = []
        for item in data {
            points.append(TrendPoint(month: item.month, amount: item.income.doubleValue, series: "Income"))
            points.append(TrendPoint(month: item.month, amount: item.expense.doubleValue, series: "Expense"))
        }
        return points
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expense Trend")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if data.isEmpty {
                emptyState
            } else {
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Month", point.month),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(by: .value("Type", point.series))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    
                    PointMark(
                        x: .value("Month", point.month),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(by: .value("Type", point.series))
                }
                .chartForegroundStyleScale([
                    "Income": Color.green,
                    "Expense": Color.red
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCompact(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 10)
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Not enough data for trends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fK", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Savings Rate Gauge
struct SavingsRateGauge: View {
    let income: Decimal
    let expense: Decimal
    let currencyCode: String
    
    private var savingsRate: Double {
        guard income > 0 else { return 0 }
        return ((income - expense) / income).doubleValue * 100
    }
    
    private var savings: Decimal {
        income - expense
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Rate")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                // Gauge
                Gauge(value: max(0, min(savingsRate, 100)), in: 0...100) {
                    Text("")
                } currentValueLabel: {
                    Text("\(Int(savingsRate))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(gaugeGradient)
                .scaleEffect(1.5)
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Savings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(MoneyFormatter.format(savings, currencyCode: currencyCode))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(savings >= 0 ? .green : .red)
                    }
                    
                    Text(savingsMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var gaugeGradient: Gradient {
        if savingsRate >= 20 {
            return Gradient(colors: [.green, .mint])
        } else if savingsRate >= 10 {
            return Gradient(colors: [.yellow, .orange])
        } else {
            return Gradient(colors: [.orange, .red])
        }
    }
    
    private var savingsMessage: String {
        if savingsRate >= 30 {
            return "Excellent! You're a super saver! 🌟"
        } else if savingsRate >= 20 {
            return "Great job! Healthy savings rate."
        } else if savingsRate >= 10 {
            return "Good start. Try to reach 20%."
        } else if savingsRate >= 0 {
            return "Consider cutting expenses."
        } else {
            return "Spending exceeds income."
        }
    }
}

// MARK: - Insights Card
struct InsightCard: View {
    let insight: InsightsGenerator.Insight
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: insight.color).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: insight.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Suggestions Card
struct SuggestionsCard: View {
    let suggestions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Smart Tips")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Budget vs Actual Chart
struct BudgetActualChart: View {
    let primaryBudget: Decimal
    let primaryActual: Decimal
    let secondaryBudget: Decimal
    let secondaryActual: Decimal
    let primaryCode: String
    let secondaryCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget vs Actual")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if primaryBudget > 0 || secondaryBudget > 0 {
                VStack(spacing: 14) {
                    if primaryBudget > 0 {
                        budgetRow(
                            label: primaryCode,
                            budget: primaryBudget,
                            actual: primaryActual,
                            currencyCode: primaryCode
                        )
                    }
                    
                    if secondaryBudget > 0 {
                        budgetRow(
                            label: secondaryCode,
                            budget: secondaryBudget,
                            actual: secondaryActual,
                            currencyCode: secondaryCode
                        )
                    }
                }
            } else {
                emptyState
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func budgetRow(label: String, budget: Decimal, actual: Decimal, currencyCode: String) -> some View {
        let percentage = budget > 0 ? min((actual / budget).doubleValue, 1.5) : 0
        let displayPercentage = min(percentage, 1.0)
        let isOverBudget = actual > budget
        let remaining = budget - actual
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor(percentage: percentage))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemGroupedBackground))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: progressGradient(percentage: percentage),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * displayPercentage)
                        .animation(.spring(response: 0.5), value: displayPercentage)
                    
                    // Over-budget indicator
                    if isOverBudget {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.red.opacity(0.5), lineWidth: 2)
                    }
                }
            }
            .frame(height: 12)
            
            // Labels
            HStack {
                Text("Spent: \(MoneyFormatter.format(actual, currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isOverBudget {
                    Text("Over by \(MoneyFormatter.format(-remaining, currencyCode: currencyCode))")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                } else {
                    Text("Left: \(MoneyFormatter.format(remaining, currencyCode: currencyCode))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private func progressColor(percentage: Double) -> Color {
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func progressGradient(percentage: Double) -> [Color] {
        if percentage >= 1.0 {
            return [.red, .pink]
        } else if percentage >= 0.8 {
            return [.orange, .yellow]
        } else {
            return [.green, .mint]
        }
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Set a budget to track spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}
