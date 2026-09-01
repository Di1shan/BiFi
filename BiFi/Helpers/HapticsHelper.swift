import SwiftUI
import UIKit

// MARK: - Haptics Helper
final class HapticsHelper {
    static let shared = HapticsHelper()
    
    private init() {}
    
    private var isEnabled: Bool = true
    
    func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
