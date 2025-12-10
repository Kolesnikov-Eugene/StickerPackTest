//
//  RLottieAnimation.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//

import Foundation
import UIKit

final class RLottieAnimation {
	
	var ref: UnsafeMutableRawPointer?
	let frameCount: Int
	
//	var fps: Int = 0
	
	init?(data: Data) {
		var animationRef: UnsafeMutableRawPointer?
		
		data.withUnsafeBytes { bytes in
			guard let baseAddress = bytes.baseAddress else { return }
			let charPointer = baseAddress.assumingMemoryBound(to: CChar.self)
			animationRef = rlottie_load_animation(charPointer, Int32(data.count))
		}
		
		guard let animationRef = animationRef else { return nil }
		self.ref = animationRef
		self.frameCount = Int(rlottie_frame_count(animationRef))
		
//		self.fps = Int(30)
		
		if frameCount == 0 {
			rlottie_destroy(animationRef)
			return nil
		}
	}
	
	deinit {
		if let ref = ref {
			rlottie_destroy(ref)
		}
	}
	
	func render(frame index: Int, size: CGSize, scale: Double) -> UIImage? {
		guard let ref = ref else { return nil }
		
//		let scale = 1.5
		let _scale = UIScreen.main.scale
		
		let width = Int(size.width * _scale)
		let height = Int(size.height * _scale)
//		let width = Int(150)
//		let height = Int(150)
		
		guard width > 0 && height > 0 else { return nil }
		
		let bufSize = width * height * 4
		
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
		defer { buffer.deallocate() }
		
		rlottie_render_frame(ref,
							 Int32(index),
							 buffer,
							 Int32(width),
							 Int32(height))
		
		let data = Data(bytes: buffer, count: bufSize)
		
		guard let provider = CGDataProvider(data: data as CFData) else { return nil }
		
		let cgImage = CGImage(
			width: width,
			height: height,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(rawValue:
				CGImageAlphaInfo.premultipliedFirst.rawValue |
				CGBitmapInfo.byteOrder32Little.rawValue
			),
			provider: provider,
			decode: nil,
			shouldInterpolate: true,
			intent: .defaultIntent
		)
		
		if let cgImage = cgImage {
			return UIImage(cgImage: cgImage)
		}
		
		return nil
	}
}

//final class RLottieAnimation {
//    
//    var ref: UnsafeMutableRawPointer?
//    let frameCount: Int
//    
//    init?(data: Data) {
//        var animationRef: UnsafeMutableRawPointer?
//        
//        data.withUnsafeBytes { bytes in
//            guard let baseAddress = bytes.baseAddress else { return }
//            let charPointer = baseAddress.assumingMemoryBound(to: CChar.self)
//            animationRef = rlottie_load_animation(charPointer, Int32(data.count))
//        }
//        
//        guard let animationRef = animationRef else { return nil }
//        self.ref = animationRef
//        self.frameCount = Int(rlottie_frame_count(animationRef))
//        
//        if frameCount == 0 {
//            rlottie_destroy(animationRef)
//            return nil
//        }
//    }
//    
//    deinit {
//        if let ref = ref {
//            rlottie_destroy(ref)
//        }
//    }
//	
//	func render(frame index: Int, size: CGSize) -> UIImage? {
//		guard let ref = ref else { return nil }
//		
//		// Use actual size with scale for proper rendering
////		let scale = UIScreen.main.scale
//		let scale = 2.0
//		let width = Int(size.width * scale)
//		let height = Int(size.height * scale)
//		print("sizes width and height - \(size.width) - \(size.height)")
//		guard width > 0 && height > 0 else { return nil }
//		
//		let bufSize = width * height * 4
//		
//		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
//		defer { buffer.deallocate() }
//		
//		rlottie_render_frame(ref,
//							 Int32(index),
//							 buffer,
//							 Int32(width),
//							 Int32(height))
//		
//		let data = Data(bytes: buffer, count: bufSize)
//		
//		guard let provider = CGDataProvider(data: data as CFData) else { return nil }
//		
//		let cgImage = CGImage(
//			width: width,
//			height: height,
//			bitsPerComponent: 8,
//			bitsPerPixel: 32,
//			bytesPerRow: width * 4,
//			space: CGColorSpaceCreateDeviceRGB(),
//			bitmapInfo: CGBitmapInfo(rawValue:
//				CGImageAlphaInfo.premultipliedFirst.rawValue |
//				CGBitmapInfo.byteOrder32Little.rawValue
//			),
//			provider: provider,
//			decode: nil,
//			shouldInterpolate: true,
//			intent: .defaultIntent
//		)
//		
//		if let cgImage = cgImage {
//			return UIImage(cgImage: cgImage)
//		}
//		
//		return nil
//	}
//}

