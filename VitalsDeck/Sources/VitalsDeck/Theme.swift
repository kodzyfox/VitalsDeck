import SwiftUI

// MARK: - Themes
public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case signalAmber = "Signal Amber"
    case matrixGreen = "Matrix Green"
    case tokyoNeon = "Tokyo Neon"
    case oledMono = "OLED Mono"
    case nordGlacier = "Nord Frost"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .signalAmber: return "SIGNAL AMBER"
        case .matrixGreen: return "MATRIX GREEN"
        case .tokyoNeon: return "TOKYO NEON"
        case .oledMono: return "OLED MONO"
        case .nordGlacier: return "NORD FROST"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .signalAmber: return "Cyberpunk Hardware Amber"
        case .matrixGreen: return "Classic Retro Phosphor CRT"
        case .tokyoNeon: return "Cyber Synthwave Dual Neon"
        case .oledMono: return "Clean Minimal Monochrome"
        case .nordGlacier: return "Arctic Slate & Polar Teal"
        }
    }
    
    // Background colors
    public var background: Color {
        switch self {
        case .signalAmber: return Color(red: 0.07, green: 0.08, blue: 0.10)
        case .matrixGreen: return Color(red: 0.02, green: 0.06, blue: 0.03)
        case .tokyoNeon:   return Color(red: 0.06, green: 0.05, blue: 0.13)
        case .oledMono:    return Color(red: 0.00, green: 0.00, blue: 0.00)
        case .nordGlacier: return Color(red: 0.12, green: 0.14, blue: 0.18)
        }
    }
    
    public var surface: Color {
        switch self {
        case .signalAmber: return Color(red: 0.11, green: 0.12, blue: 0.16)
        case .matrixGreen: return Color(red: 0.04, green: 0.10, blue: 0.05)
        case .tokyoNeon:   return Color(red: 0.10, green: 0.08, blue: 0.20)
        case .oledMono:    return Color(red: 0.09, green: 0.09, blue: 0.10)
        case .nordGlacier: return Color(red: 0.16, green: 0.18, blue: 0.23)
        }
    }
    
    public var border: Color {
        switch self {
        case .signalAmber: return Color(red: 0.85, green: 0.55, blue: 0.10).opacity(0.35)
        case .matrixGreen: return Color(red: 0.00, green: 0.90, blue: 0.35).opacity(0.35)
        case .tokyoNeon:   return Color(red: 0.00, green: 0.95, blue: 1.00).opacity(0.40)
        case .oledMono:    return Color.white.opacity(0.18)
        case .nordGlacier: return Color(red: 0.53, green: 0.75, blue: 0.82).opacity(0.35)
        }
    }
    
    // Primary Accent
    public var accent: Color {
        switch self {
        case .signalAmber: return Color(red: 1.00, green: 0.65, blue: 0.10) // Warm Amber
        case .matrixGreen: return Color(red: 0.00, green: 1.00, blue: 0.40) // Phosphor Green
        case .tokyoNeon:   return Color(red: 0.00, green: 0.95, blue: 1.00) // Electric Cyan
        case .oledMono:    return Color(red: 1.00, green: 1.00, blue: 1.00) // Pure White
        case .nordGlacier: return Color(red: 0.53, green: 0.75, blue: 0.82) // Frost Cyan
        }
    }
    
    // Secondary Accent
    public var accentSecondary: Color {
        switch self {
        case .signalAmber: return Color(red: 1.00, green: 0.38, blue: 0.15) // Deep Orange
        case .matrixGreen: return Color(red: 0.40, green: 1.00, blue: 0.20) // Lime
        case .tokyoNeon:   return Color(red: 1.00, green: 0.05, blue: 0.55) // Neon Magenta
        case .oledMono:    return Color(red: 0.65, green: 0.65, blue: 0.70) // Cool Silver
        case .nordGlacier: return Color(red: 0.51, green: 0.63, blue: 0.76) // Ice Blue
        }
    }
    
    // Text colors
    public var textPrimary: Color {
        switch self {
        case .signalAmber: return Color(red: 1.00, green: 0.96, blue: 0.88)
        case .matrixGreen: return Color(red: 0.82, green: 1.00, blue: 0.88)
        case .tokyoNeon:   return Color(red: 0.96, green: 0.95, blue: 1.00)
        case .oledMono:    return Color.white
        case .nordGlacier: return Color(red: 0.93, green: 0.94, blue: 0.96)
        }
    }
    
    public var textSecondary: Color {
        switch self {
        case .signalAmber: return Color(red: 0.70, green: 0.65, blue: 0.55)
        case .matrixGreen: return Color(red: 0.30, green: 0.70, blue: 0.40)
        case .tokyoNeon:   return Color(red: 0.65, green: 0.60, blue: 0.80)
        case .oledMono:    return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .nordGlacier: return Color(red: 0.60, green: 0.68, blue: 0.75)
        }
    }
    
    public var meterFilled: Color {
        accent
    }
    
    public var meterEmpty: Color {
        switch self {
        case .signalAmber: return Color(red: 0.25, green: 0.18, blue: 0.08)
        case .matrixGreen: return Color(red: 0.08, green: 0.22, blue: 0.10)
        case .tokyoNeon:   return Color(red: 0.20, green: 0.12, blue: 0.32)
        case .oledMono:    return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .nordGlacier: return Color(red: 0.22, green: 0.27, blue: 0.34)
        }
    }
    
    public var badgeBackground: Color {
        accent.opacity(0.15)
    }
    
    /// Generates ASCII representation: ███████░░
    public func asciiBar(fraction: Double, length: Int = 10) -> String {
        let clamped = max(0.0, min(1.0, fraction))
        let filledCount = Int((clamped * Double(length)).rounded())
        let emptyCount = max(0, length - filledCount)
        return String(repeating: "█", count: filledCount) + String(repeating: "░", count: emptyCount)
    }
}
