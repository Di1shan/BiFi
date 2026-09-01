import Foundation

// MARK: - Month Helpers
struct MonthHelper {
    
    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
    
    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    /// Returns month key in YYYY-MM format
    static func monthKey(from date: Date) -> String {
        monthKeyFormatter.string(from: date)
    }
    
    /// Returns Date from month key (YYYY-MM)
    static func date(from monthKey: String) -> Date? {
        monthKeyFormatter.date(from: monthKey)
    }
    
    /// Returns formatted month title (e.g., "February 2026")
    static func monthTitle(from date: Date) -> String {
        monthTitleFormatter.string(from: date)
    }
    
    /// Returns formatted month title from month key
    static func monthTitle(from monthKey: String) -> String {
        guard let date = date(from: monthKey) else { return monthKey }
        return monthTitle(from: date)
    }
    
    /// Returns the start of the month for a given date
    static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns the end of the month for a given date
    static func endOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(for: date)) else {
            return date
        }
        return calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? date
    }
    
    /// Returns the start of the month from month key
    static func startOfMonth(from monthKey: String) -> Date? {
        guard let date = date(from: monthKey) else { return nil }
        return startOfMonth(for: date)
    }
    
    /// Returns the end of the month from month key
    static func endOfMonth(from monthKey: String) -> Date? {
        guard let date = date(from: monthKey) else { return nil }
        return endOfMonth(for: date)
    }
    
    /// Returns the previous month date
    static func previousMonth(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
    }
    
    /// Returns the next month date
    static func nextMonth(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
    }
    
    /// Returns formatted day header (e.g., "Monday, February 5")
    static func dayHeader(from date: Date) -> String {
        dayHeaderFormatter.string(from: date)
    }
    
    /// Check if a date is in the current month
    static func isCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    /// Returns current month key
    static var currentMonthKey: String {
        monthKey(from: Date())
    }
}

// MARK: - Financial Month Helper
struct FinancialMonthHelper {
    
    // MARK: - Core Logic
    
    /// Clamps a desired day to the valid range for a specific month/year
    /// e.g. Feb 2024 (Leap), desired 31 -> 29
    static func clampedDay(for year: Int, month: Int, desiredDay: Int, calendar: Calendar = .current) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 1
        }
        
        return min(desiredDay, range.count)
    }
    
    /// Returns the financial period details for a given date
    static func financialPeriod(containing date: Date, startDay: Int, calendar: Calendar = .current) -> (start: Date, endExclusive: Date, displayEnd: Date, key: String, title: String, rangeDescription: String) {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Clamped start day for THIS calendar month
        let effectiveStartDayThisMonth = clampedDay(for: year, month: month, desiredDay: startDay, calendar: calendar)
        
        var periodStart: Date
        
        if day >= effectiveStartDayThisMonth {
            // We are inside the period starting this month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = effectiveStartDayThisMonth
            periodStart = calendar.date(from: components) ?? date
        } else {
            // We are in the period that started last month
            // Go back one month
            let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: date)!
            let pYear = calendar.component(.year, from: prevMonthDate)
            let pMonth = calendar.component(.month, from: prevMonthDate)
            let effectiveStartDayPrevMonth = clampedDay(for: pYear, month: pMonth, desiredDay: startDay, calendar: calendar)
            
            var components = DateComponents()
            components.year = pYear
            components.month = pMonth
            components.day = effectiveStartDayPrevMonth
            periodStart = calendar.date(from: components) ?? prevMonthDate
        }
        
        // Calculate endExclusive (Start of NEXT financial period)
        // Logic: The next period starts roughly +1 month from periodStart.
        // BUT strict +1 month might land on a clamped day differently if we just add components.
        // Better definition: The next period represents the NEXT month's start day.
        

        
        // Target next month
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: periodStart)! // Rough valid date in next month
        let nextYear = calendar.component(.year, from: nextMonthDate)
        let nextMonth = calendar.component(.month, from: nextMonthDate)
        
        let effectiveStartNextMonth = clampedDay(for: nextYear, month: nextMonth, desiredDay: startDay, calendar: calendar)
        
        var nextComponents = DateComponents()
        nextComponents.year = nextYear
        nextComponents.month = nextMonth
        nextComponents.day = effectiveStartNextMonth
        
        let endExclusive = calendar.date(from: nextComponents) ?? nextMonthDate
        
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: endExclusive)!
        
        // Formatter for Key
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM" // Sticking to existing format derived from start date
        let key = keyFormatter.string(from: periodStart)
        
        // Formatters for Title
        let title: String
        
        if startDay == 1 {
            let simpleMonthFormatter = DateFormatter()
            simpleMonthFormatter.dateFormat = "MMMM yyyy"
            title = simpleMonthFormatter.string(from: periodStart)
        } else {
            // Determine which month has more days in this period
            let startMonthComp = calendar.component(.month, from: periodStart)
            let endMonthComp = calendar.component(.month, from: displayEnd)
            
            let targetDate: Date
            
            if startMonthComp == endMonthComp {
                // Should technically be covered by startDay == 1 usually, but fallback safer
                targetDate = periodStart
            } else {
                let startMonthRange = calendar.range(of: .day, in: .month, for: periodStart) ?? 0..<30
                let startDayVal = calendar.component(.day, from: periodStart)
                let daysInStartMonth = startMonthRange.count - startDayVal + 1
                
                let daysInEndMonth = calendar.component(.day, from: displayEnd)
                
                targetDate = daysInEndMonth > daysInStartMonth ? displayEnd : periodStart
            }
            
            let simpleMonthFormatter = DateFormatter()
            simpleMonthFormatter.dateFormat = "MMMM yyyy"
            title = simpleMonthFormatter.string(from: targetDate)
        }
        
        // Range Description (Always full range)
        let rangeDescription: String
        let startMonthF = DateFormatter()
        startMonthF.dateFormat = "MMM d"
        let endMonthF = DateFormatter()
        // Be smart about year
        let sameYear = calendar.component(.year, from: periodStart) == calendar.component(.year, from: displayEnd)
        if sameYear {
            endMonthF.dateFormat = "MMM d, yyyy"
        } else {
            startMonthF.dateFormat = "MMM d, yyyy"
            endMonthF.dateFormat = "MMM d, yyyy"
        }
        rangeDescription = "\(startMonthF.string(from: periodStart)) – \(endMonthF.string(from: displayEnd))"
        
        return (periodStart, endExclusive, displayEnd, key, title, rangeDescription)
    }
    
    /// Shifts an anchor date by N financial months
    static func shiftFinancialAnchor(_ anchor: Date, by months: Int, startDay: Int, calendar: Calendar = .current) -> Date {
        // 1. Identify current period start
        let currentPeriod = financialPeriod(containing: anchor, startDay: startDay, calendar: calendar)
        
        // 2. Add 'months' to the current period's start month component
        //    (Just jumping by calendar months on the start date is usually safe enough to land in the target month,
        //     then we re-clamp)
        
        guard let targetMonthRough = calendar.date(byAdding: .month, value: months, to: currentPeriod.start) else {
            return anchor
        }
        
        // 3. Re-calculate the specific start date for that target month
        //    Wait, simply adding 1 month to "Jan 31" gives "Feb 28".
        //    If we want to maintain the "startDay" preference, we should explicitly construct it.
        
        let year = calendar.component(.year, from: targetMonthRough)
        let month = calendar.component(.month, from: targetMonthRough)
        
        let effectiveDay = clampedDay(for: year, month: month, desiredDay: startDay, calendar: calendar)
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = effectiveDay
        
        return calendar.date(from: components) ?? targetMonthRough
    }
}
