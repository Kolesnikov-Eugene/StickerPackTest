import UIKit

// Simplified version without UIKitRuntimeUtils dependency
// For full functionality, you may need to extract UIKitRuntimeUtils module

public extension UIView {
    static func animationDurationFactor() -> Double {
        // Default implementation - returns 1.0
        // In full Telegram implementation, this uses UIKitRuntimeUtils
        return 1.0
    }
}

public let UIScreenScale = UIScreen.main.scale
public func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}
public func ceilToScreenPixels(_ value: CGFloat) -> CGFloat {
    return ceil(value * UIScreenScale) / UIScreenScale
}

public let UIScreenPixel = 1.0 / UIScreenScale

public extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
    }
    
    convenience init(argb: UInt32) {
        self.init(red: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0.0
        if self.getRed(nil, green: nil, blue: nil, alpha: &alpha) {
            return alpha
        } else if self.getWhite(nil, alpha: &alpha) {
            return alpha
        } else {
            return 0.0
        }
    }
    
    func withMultipliedAlpha(_ alpha: CGFloat) -> UIColor {
        var r1: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var a1: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) {
            return UIColor(red: r1, green: g1, blue: b1, alpha: max(0.0, min(1.0, a1 * alpha)))
        }
        return self
    }
}

