import SwiftUI

enum BrandColors {
    /// Mockup-aligned Hello Tuk-Tuk palette
    static let teal = Color(red: 0.0, green: 0.702, blue: 0.651) // #00B3A6
    static let tealDark = Color(red: 0.055, green: 0.580, blue: 0.549) // #0E948C
    static let gold = Color(red: 0.973, green: 0.718, blue: 0.157) // #F8B728
    static let goldDark = Color(red: 0.902, green: 0.659, blue: 0.0)
    static let navy = Color(red: 0.067, green: 0.094, blue: 0.153) // #111827
    static let surface = Color(red: 0.953, green: 0.957, blue: 0.965) // #F3F4F6
    static let muted = Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280
    static let border = Color(red: 0.898, green: 0.906, blue: 0.922) // #E5E7EB
    static let success = Color(red: 0.086, green: 0.639, blue: 0.290)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let danger = Color(red: 0.863, green: 0.149, blue: 0.149)
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum AppRadii {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}
