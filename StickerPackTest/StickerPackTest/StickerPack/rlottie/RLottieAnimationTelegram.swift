//
//  RLottieAnimationTelegram.swift
//  StickerPackTest
//
//  Created based on Telegram's implementation approach
//

import Foundation
import UIKit
import CoreGraphics

final class RLottieAnimationTelegram {
    
    var ref: UnsafeMutableRawPointer?
    let frameCount: Int
    let width: Int
    let height: Int
    let frameRate: Double
    
    init?(data: Data, fitzModifier: Int = 0) {
        var animationRef: UnsafeMutableRawPointer?
        
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let charPointer = baseAddress.assumingMemoryBound(to: CChar.self)
            animationRef = lottie_instance_create(charPointer, Int32(data.count), Int32(fitzModifier))
        }
        
        guard let animationRef = animationRef else { return nil }
        self.ref = animationRef
        self.frameCount = Int(lottie_instance_frame_count(animationRef))
        self.width = Int(lottie_instance_width(animationRef))
        self.height = Int(lottie_instance_height(animationRef))
        self.frameRate = lottie_instance_frame_rate(animationRef)
        
        if frameCount == 0 || width == 0 || height == 0 {
            lottie_instance_destroy(animationRef)
            return nil
        }
    }
    
    deinit {
        if let ref = ref {
            lottie_instance_destroy(ref)
        }
    }
    
    func render(frame index: Int, size: CGSize, scale: Double) -> UIImage? {
        guard let ref = ref else { return nil }
        
        let screenScale = UIScreen.main.scale
        let renderWidth = Int(size.width * screenScale)
        let renderHeight = Int(size.height * screenScale)
        
        guard renderWidth > 0 && renderHeight > 0 else { return nil }
        
        let bytesPerRow = renderWidth * 4
        let bufSize = renderHeight * bytesPerRow
        
        // Allocate buffer with proper alignment
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        
        // Clear buffer (important for transparency)
        buffer.initialize(repeating: 0, count: bufSize)
        
        // Render frame - rlottie renders in RGBA format
        lottie_instance_render_frame(ref,
                                     Int32(index),
                                     buffer,
                                     Int32(renderWidth),
                                     Int32(renderHeight),
                                     Int32(bytesPerRow))
        
        // Convert RGBA buffer to UIImage
        // rlottie renders in RGBA format (R, G, B, A bytes)
        // iOS CGImage can work with RGBA format using the correct bitmap info
        return createImageFromRGBA(buffer: buffer,
                                     width: renderWidth,
                                     height: renderHeight,
                                     bytesPerRow: bytesPerRow)
    }
    
    private func createImageFromRGBA(buffer: UnsafeMutablePointer<UInt8>,
                                     width: Int,
                                     height: Int,
                                     bytesPerRow: Int) -> UIImage? {
        // Buffer is already converted to ARGB (premultiplied) in C++ layer
        // This is much faster than doing it in Swift
        
        // Create data provider from buffer
        let bufferSize = height * bytesPerRow
        let data = Data(bytesNoCopy: buffer, count: bufferSize, deallocator: .none)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        
        // Use sRGB color space for accurate color reproduction
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        
        // Create CGImage with premultiplied ARGB format
        // Buffer is already in ARGB (premultiplied) format from C++ conversion
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedFirst.rawValue | // ARGB format
            CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
}

