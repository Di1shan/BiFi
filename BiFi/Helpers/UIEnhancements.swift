import SwiftUI

// MARK: - App Theme
struct AppTheme {
    // Vibrant gradient colors
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "#11998e"), Color(hex: "#38ef7d")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let expenseGradient = LinearGradient(
        colors: [Color(hex: "#eb3349"), Color(hex: "#f45c43")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient1 = LinearGradient(
        colors: [Color(hex: "#4facfe"), Color(hex: "#00f2fe")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient2 = LinearGradient(
        colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient3 = LinearGradient(
        colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient4 = LinearGradient(
        colors: [Color(hex: "#a8edea"), Color(hex: "#fed6e3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkCardGradient = LinearGradient(
        colors: [Color(hex: "#2c3e50"), Color(hex: "#3498db")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Accent colors
    static let accentBlue = Color(hex: "#667eea")
    static let accentPurple = Color(hex: "#764ba2")
    static let accentGreen = Color(hex: "#38ef7d")
    static let accentPink = Color(hex: "#fa709a")
    static let accentOrange = Color(hex: "#f5576c")
    static let accentCyan = Color(hex: "#00f2fe")
}

// MARK: - Animated Card Modifier
struct AnimatedCardModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulse Animation
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Gradient Card Style
struct GradientCardStyle: ViewModifier {
    let gradient: LinearGradient
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Glass Card Style
struct GlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
    }
}

// MARK: - Number Animation
struct AnimatedNumber: View {
    let value: Decimal
    let currencyCode: String
    let font: Font
    let color: Color
    
    @State private var displayValue: Double = 0
    
    var body: some View {
        Text(MoneyFormatter.format(Decimal(displayValue), currencyCode: currencyCode))
            .font(font)
            .fontWeight(.bold)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    displayValue = NSDecimalNumber(decimal: value).doubleValue
                }
            }
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.easeOut(duration: 0.5)) {
                    displayValue = NSDecimalNumber(decimal: newValue).doubleValue
                }
            }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticsHelper.shared.impact()
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(gradient)
                .clipShape(Circle())
                .shadow(color: AppTheme.accentPurple.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Animated Icon
struct AnimatedIcon: View {
    let icon: String
    let color: Color
    
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(color)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func animatedCard(delay: Double = 0) -> some View {
        modifier(AnimatedCardModifier(delay: delay))
    }
    
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
    
    func pulse() -> some View {
        modifier(PulseModifier())
    }
    
    func gradientCard(_ gradient: LinearGradient, cornerRadius: CGFloat = 16) -> some View {
        modifier(GradientCardStyle(gradient: gradient, cornerRadius: cornerRadius))
    }
    
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var isAnimating = false
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50) { i in
                Circle()
                    .fill(colors.randomElement()!)
                    .frame(width: CGFloat.random(in: 4...8))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: isAnimating ? geometry.size.height + 20 : -20
                    )
                    .animation(
                        .easeIn(duration: Double.random(in: 1...3)).delay(Double(i) * 0.02),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 30)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Transaction Row Animated
struct AnimatedTransactionRow: View {
    let transaction: Transaction
    let category: Category?
    let currencyCode: String
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(Color(hex: category?.colorHex ?? "#808080").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category?.icon ?? "tag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: category?.colorHex ?? "#808080"))
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note.isEmpty ? (category?.name ?? "Uncategorized") : transaction.note)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(MoneyFormatter.format(transaction.amount, currencyCode: currencyCode))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .income ? AppTheme.accentGreen : .primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.primaryGradient)
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Capsule())
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(40)
        .onAppear { isAnimating = true }
    }
}
// MARK: - Tab Bar Components
enum TabItem: Int, CaseIterable {
    case dashboard = 0
    case transactions = 1
    case budgets = 2
    case settings = 3
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transactions: return "Transactions"
        case .budgets: return "Budgets"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .budgets: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedTab = tab
                        HapticsHelper.shared.selection()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 24))
                            .symbolEffect(.bounce, value: selectedTab == tab)
                        
                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(selectedTab == tab ? AppTheme.accentPurple : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .matchedGeometryEffect(id: "activeTab", in: namespace)
                        }
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.bottom, 20) // Safe area padding
    }
}

// MARK: - Shake Animation
struct ShakeModifier: ViewModifier {
    @State private var shake = false
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: shake ? -5 : 0)
            .animation(
                shake ? Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true) : .default,
                value: shake
            )
            .onChange(of: trigger) { _, _ in
                shake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shake = false
                }
            }
    }
}

// MARK: - Wiggle Animation
struct WiggleModifier: ViewModifier {
    @State private var isWiggling = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? 2 : -2))
            .animation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true), value: isWiggling)
            .onAppear { isWiggling = true }
    }
}

// MARK: - Glow Animation
struct GlowModifier: ViewModifier {
    let color: Color
    @State private var isGlowing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.6 : 0.2), radius: isGlowing ? 15 : 5)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isGlowing)
            .onAppear { isGlowing = true }
    }
}

// MARK: - Typing Animation Text
struct TypewriterText: View {
    let text: String
    let speed: Double
    
    @State private var displayedText = ""
    @State private var charIndex = 0
    
    init(_ text: String, speed: Double = 0.05) {
        self.text = text
        self.speed = speed
    }
    
    var body: some View {
        Text(displayedText)
            .onAppear {
                animate()
            }
    }
    
    private func animate() {
        guard charIndex < text.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            displayedText += String(text[text.index(text.startIndex, offsetBy: charIndex)])
            charIndex += 1
            animate()
        }
    }
}

// MARK: - Slide In From Edge
struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(
                x: isVisible ? 0 : (edge == .leading ? -100 : (edge == .trailing ? 100 : 0)),
                y: isVisible ? 0 : (edge == .top ? -50 : (edge == .bottom ? 50 : 0))
            )
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Flip Card
struct FlipCardModifier: ViewModifier {
    @Binding var isFlipped: Bool
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
    }
}

// MARK: - Scale On Appear
struct ScaleOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.5
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Parallax Effect
struct ParallaxModifier: ViewModifier {
    let magnitude: CGFloat
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                // This would typically be connected to scroll position
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = magnitude
                }
            }
    }
}

// MARK: - Breathing Animation
struct BreathingModifier: ViewModifier {
    @State private var isBreathing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBreathing ? 1.03 : 0.97)
            .opacity(isBreathing ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isBreathing)
            .onAppear { isBreathing = true }
    }
}

// MARK: - Morph Animation
struct MorphModifier: ViewModifier {
    @State private var morphPhase = 0.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1 + sin(morphPhase) * 0.03, y: 1 + cos(morphPhase) * 0.03)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    morphPhase = .pi * 2
                }
            }
    }
}

// MARK: - Gradient Shift Animation
struct GradientShiftModifier: ViewModifier {
    @State private var gradientStart = UnitPoint.topLeading
    @State private var gradientEnd = UnitPoint.bottomTrailing
    
    let colors: [Color]
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: gradientStart, endPoint: gradientEnd)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    gradientStart = UnitPoint.bottomTrailing
                    gradientEnd = UnitPoint.topLeading
                }
            }
    }
}

// MARK: - Count Up Animation
struct CountUpText: View {
    let value: Int
    let duration: Double
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        Text("\(displayValue)")
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, newValue in
                animateValue()
            }
    }
    
    private func animateValue() {
        let steps = 30
        let stepDuration = duration / Double(steps)
        let increment = value / steps
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                if i == steps {
                    displayValue = value
                } else {
                    displayValue = increment * i
                }
            }
        }
    }
}

// MARK: - Spring List Row
struct SpringRowModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .offset(x: isVisible ? 0 : 50)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Elastic Button Style
struct ElasticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 10), value: configuration.isPressed)
    }
}

// MARK: - Jelly Button Style
struct JellyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 1.1 : 1.0, y: configuration.isPressed ? 0.9 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 8), value: configuration.isPressed)
    }
}

// MARK: - Rotating Border
struct RotatingBorderModifier: ViewModifier {
    @State private var rotation: Double = 0
    let lineWidth: CGFloat
    let gradient: LinearGradient
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(gradient, lineWidth: lineWidth)
                    .rotationEffect(.degrees(rotation))
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Floating Animation
struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    let magnitude: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -magnitude : magnitude)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isFloating)
            .onAppear { isFloating = true }
    }
}

// MARK: - Pulsing Ring
struct PulsingRingView: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.5 + CGFloat(i) * 0.3 : 1)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.3),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Success Checkmark
struct AnimatedCheckmark: View {
    @State private var isAnimating = false
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .scaleEffect(isAnimating ? 1 : 0)
            
            Image(systemName: "checkmark")
                .font(.title.weight(.bold))
                .foregroundColor(color)
                .scaleEffect(isAnimating ? 1 : 0)
                .rotationEffect(.degrees(isAnimating ? 0 : -90))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Morphing Loading Dots
struct LoadingDotsView: View {
    @State private var animationPhase = 0
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animationPhase == index ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Wave Animation Text
struct WaveTextModifier: ViewModifier {
    @State private var wavePhase: Double = 0
    let amplitude: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: sin(wavePhase) * amplitude)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    wavePhase = .pi
                }
            }
    }
}

// MARK: - Extended View Extensions
extension View {
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
    
    func wiggle() -> some View {
        modifier(WiggleModifier())
    }
    
    func glow(_ color: Color = .blue) -> some View {
        modifier(GlowModifier(color: color))
    }
    
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        modifier(SlideInModifier(edge: edge, delay: delay))
    }
    
    func flipCard(isFlipped: Binding<Bool>) -> some View {
        modifier(FlipCardModifier(isFlipped: isFlipped))
    }
    
    func scaleOnAppear(delay: Double = 0) -> some View {
        modifier(ScaleOnAppearModifier(delay: delay))
    }
    
    func parallax(magnitude: CGFloat = 10) -> some View {
        modifier(ParallaxModifier(magnitude: magnitude))
    }
    
    func breathing() -> some View {
        modifier(BreathingModifier())
    }
    
    func morph() -> some View {
        modifier(MorphModifier())
    }
    
    func springRow(index: Int) -> some View {
        modifier(SpringRowModifier(index: index))
    }
    
    func floating(magnitude: CGFloat = 5) -> some View {
        modifier(FloatingModifier(magnitude: magnitude))
    }
    
    func wave(amplitude: CGFloat = 5) -> some View {
        modifier(WaveTextModifier(amplitude: amplitude))
    }
    
    func rotatingBorder(lineWidth: CGFloat = 2, gradient: LinearGradient = AppTheme.primaryGradient) -> some View {
        modifier(RotatingBorderModifier(lineWidth: lineWidth, gradient: gradient))
    }
}

// MARK: - Animated Icon Button
struct AnimatedIconButton: View {
    let icon: String
    let selectedIcon: String
    @Binding var isSelected: Bool
    let color: Color
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isSelected.toggle()
            }
            HapticsHelper.shared.impact(.light)
        } label: {
            Image(systemName: isSelected ? selectedIcon : icon)
                .font(.title2)
                .foregroundColor(isSelected ? color : .gray)
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .rotationEffect(.degrees(isSelected ? 360 : 0))
        }
    }
}

// MARK: - Particle Effect
struct ParticleEffectView: View {
    let particleCount: Int
    let colors: [Color]
    
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(colors.randomElement() ?? .white)
                    .frame(width: 6, height: 6)
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            startParticles()
        }
    }
    
    private func startParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if particles.count < particleCount {
                let newParticle = (
                    id: particles.count,
                    x: CGFloat.random(in: 0...300),
                    y: CGFloat.random(in: 0...300),
                    opacity: 1.0
                )
                particles.append(newParticle)
            }
            
            // Animate existing particles
            for i in particles.indices {
                withAnimation(.easeOut(duration: 1)) {
                    particles[i].opacity = 0
                }
            }
            
            // Remove faded particles
            particles = particles.filter { $0.opacity > 0.1 }
        }
    }
}
