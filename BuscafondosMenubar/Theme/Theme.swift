import SwiftUI

// MARK: - Institutional Glass palette (from DESIGN.md + dashboard tailwind config)
enum Palette {
    static let primary             = Color(hex: 0x001E40)
    static let primaryContainer    = Color(hex: 0x003366)
    static let secondary           = Color(hex: 0x00629F)
    static let secondaryContainer  = Color(hex: 0x5CB1FF)
    static let onSecondaryContainer = Color(hex: 0x00426E)
    static let tertiary            = Color(hex: 0x1D1E1F)
    static let error               = Color(hex: 0xBA1A1A)

    static let surface                  = Color(hex: 0xF8F9FA)
    static let surfaceContainerLowest   = Color(hex: 0xFFFFFF)
    static let surfaceContainerLow      = Color(hex: 0xF3F4F5)
    static let surfaceContainer         = Color(hex: 0xEDEEEF)
    static let surfaceContainerHigh     = Color(hex: 0xE7E8E9)
    static let surfaceContainerHighest  = Color(hex: 0xE1E3E4)

    static let onSurface         = Color(hex: 0x191C1D)
    static let onSurfaceVariant  = Color(hex: 0x43474F)
    static let outlineVariant    = Color(hex: 0xC3C6D1)

    // Dark variants (approximation for vibrancy popover over dark wallpapers)
    static let primaryDark        = Color(hex: 0x001B3C)
    static let onSurfaceDark      = Color(hex: 0xE1E3E4)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Typography (Institutional Glass editorial)
enum Typography {
    static let displayLG: Font = .system(size: 36, weight: .bold, design: .default)
        .monospacedDigit()
    static let displayMD: Font = .system(size: 28, weight: .bold, design: .default)
        .monospacedDigit()
    static let titleLG: Font = .system(size: 18, weight: .bold)
    static let titleMD: Font = .system(size: 14, weight: .bold)
    static let titleSM: Font = .system(size: 13, weight: .semibold)
    static let bodyMD: Font = .system(size: 12, weight: .medium)
    static let labelMD: Font = .system(size: 11, weight: .semibold)
    static let labelSM: Font = .system(size: 10, weight: .semibold)
    static let labelXS: Font = .system(size: 9, weight: .bold)
    static let money: Font = .system(size: 14, weight: .bold).monospacedDigit()
    static let moneyLG: Font = .system(size: 36, weight: .bold).monospacedDigit()
    static let moneyMD: Font = .system(size: 18, weight: .bold).monospacedDigit()
    static let moneySM: Font = .system(size: 12, weight: .semibold).monospacedDigit()
}

// MARK: - Spacing (Stitch scale)
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - Chilean formatters
enum Formatters {
    static let cl: Locale = Locale(identifier: "es_CL")

    static let clp: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = cl
        f.numberStyle = .currency
        f.currencyCode = "CLP"
        f.maximumFractionDigits = 0
        return f
    }()

    static let clpSigned: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = cl
        f.numberStyle = .currency
        f.currencyCode = "CLP"
        f.maximumFractionDigits = 0
        f.positivePrefix = "+" + (f.currencySymbol ?? "$")
        return f
    }()

    static let cuotas: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = cl
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        return f
    }()

    static let percent: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = cl
        f.numberStyle = .percent
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.positivePrefix = "+"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = cl
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static func clp(_ value: Decimal) -> String {
        clp.string(from: value as NSDecimalNumber) ?? "—"
    }

    static func clpSigned(_ value: Decimal) -> String {
        clpSigned.string(from: value as NSDecimalNumber) ?? "—"
    }

    static func percent(_ fraction: Double) -> String {
        percent.string(from: NSNumber(value: fraction)) ?? "—"
    }
}
