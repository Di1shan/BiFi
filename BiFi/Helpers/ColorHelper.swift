import SwiftUI

// MARK: - Color from Hex Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let r, g, b: CGFloat
        if components.count >= 3 {
            r = components[0]
            g = components[1]
            b = components[2]
        } else {
            r = components[0]
            g = components[0]
            b = components[0]
        }
        
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )
    }
}

// MARK: - Preset Colors for Categories
extension Color {
    static let categoryColors: [Color] = categoryColorHexes.map { Color(hex: $0) }
    
    static let categoryColorHexes: [String] = [
        // Vibrant Colors
        "#FF6B6B", // Coral Red
        "#FF8A80", // Salmon
        "#FF6B9D", // Pink
        "#E91E63", // Deep Pink
        "#9C27B0", // Purple
        "#DDA0DD", // Plum
        "#673AB7", // Deep Purple
        "#3F51B5", // Indigo
        "#4D96FF", // Blue
        "#45B7D1", // Sky Blue
        "#00BCD4", // Cyan
        "#4ECDC4", // Teal
        "#009688", // Dark Teal
        "#6BCB77", // Green
        "#4CAF50", // Material Green
        "#96CEB4", // Sage
        "#98D8C8", // Mint
        "#8BC34A", // Light Green
        "#CDDC39", // Lime
        "#FFD93D", // Yellow
        "#FFC107", // Amber
        "#FF9800", // Orange
        "#FF5722", // Deep Orange
        "#795548", // Brown
        "#607D8B", // Blue Grey
        "#B8B8B8"  // Grey
    ]
}

// MARK: - Color Helper Utilities
struct ColorHelper {
    /// Returns a random category color hex string
    static func randomCategoryColor() -> String {
        Color.categoryColorHexes.randomElement() ?? "#4ECDC4"
    }
}
