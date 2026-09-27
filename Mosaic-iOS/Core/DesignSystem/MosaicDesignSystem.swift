import SwiftUI

enum MosaicColor {
    static let background = Color(red: 0.045, green: 0.05, blue: 0.075)
    static let surface = Color.white.opacity(0.10)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.66)
    static let accent = Color(red: 0.60, green: 0.73, blue: 1.0)
}

enum MosaicSpace { static let small: CGFloat = 8; static let medium: CGFloat = 16; static let large: CGFloat = 24 }
enum MosaicRadius { static let card: CGFloat = 18; static let control: CGFloat = 12 }
enum MosaicType { static let wordmark = Font.system(size: 26, weight: .bold, design: .rounded); static let title = Font.system(.title2, design: .rounded, weight: .semibold); static let body = Font.body }
