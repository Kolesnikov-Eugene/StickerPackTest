import UIKit

// Simplified version without UIKitRuntimeUtils dependency
// For full functionality, you may need to extract UIKitRuntimeUtils module

@objc private class CALayerAnimationDelegate: NSObject, CAAnimationDelegate {
    private let keyPath: String?
    var completion: ((Bool) -> Void)?
    
    init(animation: CAAnimation, completion: ((Bool) -> Void)?) {
        if let animation = animation as? CABasicAnimation {
            self.keyPath = animation.keyPath
        } else {
            self.keyPath = nil
        }
        self.completion = completion
        
        super.init()
    }
    
    @objc func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let anim = anim as? CABasicAnimation {
            if anim.keyPath != self.keyPath {
                return
            }
        }
        if let completion = self.completion {
            completion(flag)
            self.completion = nil
        }
    }
}

private func adjustFrameRate(animation: CAAnimation) {
    if #available(iOS 15.0, *) {
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        if maxFps > 61.0 {
            var preferredFps: Float = maxFps
            if let animation = animation as? CABasicAnimation {
                if animation.keyPath == "opacity" {
                    preferredFps = 60.0
                    return
                }
            }
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: preferredFps, preferred: maxFps)
        }
    }
}

public extension CALayer {
    func makeAnimation(from: Any?, to: Any, keyPath: String, timingFunction: String, duration: Double, delay: Double = 0.0, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) -> CAAnimation {
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        if let mediaTimingFunction = mediaTimingFunction {
            animation.timingFunction = mediaTimingFunction
        } else {
            switch timingFunction {
            case CAMediaTimingFunctionName.linear.rawValue, CAMediaTimingFunctionName.easeIn.rawValue, CAMediaTimingFunctionName.easeOut.rawValue, CAMediaTimingFunctionName.easeInEaseOut.rawValue, CAMediaTimingFunctionName.default.rawValue:
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName(rawValue: timingFunction))
            default:
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            }
        }
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        animation.speed = speed
        animation.isAdditive = additive
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
        }
        
        if !delay.isZero {
            animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor()
            animation.fillMode = .both
        }
        
        adjustFrameRate(animation: animation)
        
        return animation
    }
    
    func animate(from: Any?, to: Any, keyPath: String, timingFunction: String, duration: Double, delay: Double = 0.0, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil, key: String? = nil) {
        let animation = self.makeAnimation(from: from, to: to, keyPath: keyPath, timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
        self.add(animation, forKey: key ?? (additive ? nil : keyPath))
    }
    
    func animateAlpha(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, mediaTimingFunction: CAMediaTimingFunction? = nil, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "opacity", timingFunction: timingFunction, duration: duration, delay: delay, mediaTimingFunction: mediaTimingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
    }
}

