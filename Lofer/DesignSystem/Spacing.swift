import SwiftUI

/// Spacing and corner radii, so layouts use the same rhythm everywhere.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let chip: CGFloat = 17
    static let button: CGFloat = 24
    static let card: CGFloat = 20
    static let sheet: CGFloat = 32
}

/// Motion: slow enough to feel premium, quick enough to feel direct.
enum Motion {
    static let standard = Animation.timingCurve(0.22, 0.7, 0.12, 1, duration: 0.6)
    static let slow = Animation.timingCurve(0.22, 0.7, 0.12, 1, duration: 1.1)
}
