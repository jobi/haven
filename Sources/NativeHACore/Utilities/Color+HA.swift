import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // MARK: - Brand Tokens
    public static let haBlue = Color(hex: "#03A9F4")
    public static let haBlueDark = Color(hex: "#0288D1")
    public static let haOrange = Color(hex: "#FF9800")
    
    // MARK: - State & Domain Colors
    public static let haLightActive = Color(hex: "#FDD835")      // Amber / Warm Yellow
    public static let haSwitchActive = Color(hex: "#00E676")     // Green
    public static let haClimateHeating = Color(hex: "#FF5722")  // Orange-Red
    public static let haClimateCooling = Color(hex: "#2196F3")  // Cyan / Cool Blue
    public static let haUnavailable = Color(hex: "#9E9E9E")     // Neutral Gray
    public static let haAlarmArmed = Color(hex: "#E53935")      // Alert Red
    public static let haAlarmDisarmed = Color(hex: "#43A047")   // Safe Green
    
    // MARK: - Semantic Surfaces
    public static var haBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    public static var haCardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    public static var haCardBackgroundElevated: Color {
        #if os(iOS)
        return Color(uiColor: .tertiarySystemGroupedBackground)
        #else
        return Color(nsColor: .underPageBackgroundColor)
        #endif
    }
    
    // MARK: - Hex Initializer
    public init(hex: String) {
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
}
