//
//  RLottieAnimation.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//

import Foundation
import UIKit
import Accelerate

public protocol RLottieAnimationProtocol {
	var ref: UnsafeMutableRawPointer? { get set }
	var frameCount: Int { get }
	var progress: CGFloat { get }
	var duration: TimeInterval { get }
//	var playbackMode: PlaybackMode { get set }
	func renderNextFrame(size: CGSize) -> UIImage?
	func resetAnimationStateToDefault()
}

public class RLottieAnimation {
	
	public var ref: UnsafeMutableRawPointer?
	public let frameCount: Int
	public var progress: CGFloat {
		guard state.frameCount > 0 else { return 0 }
		return CGFloat(state.currentFrame) / CGFloat(state.frameCount)
	}
	public var duration: TimeInterval {
		Double(state.frameCount) / Double(state.targetFps)
	}
	
	private var state: AnimationState
//	public var playbackMode: PlaybackMode = .loop
	
	private struct AnimationState {
		var currentFrame: Int = 0
		var frameCount: Int = 0
		var targetFps: Int = 60
	}
	
	private var pixelBuffer: UnsafeMutablePointer<UInt8>?
	private var pixelBufferSize: Int = 0
	private var pixelBufferWidth: Int = 0
	private var pixelBufferHeight: Int = 0
	
	public init?(data: Data) {
		var animationRef: UnsafeMutableRawPointer?
		
		data.withUnsafeBytes { bytes in
			guard let baseAddress = bytes.baseAddress else { return }
			let charPointer = baseAddress.assumingMemoryBound(to: CChar.self)
			animationRef = rlottie_load_animation(charPointer, Int32(data.count))
		}
		
		guard let animationRef = animationRef else { return nil }
		self.ref = animationRef
		self.frameCount = Int(rlottie_frame_count(animationRef))
		
		self.state = .init(currentFrame: 0, frameCount: frameCount)
		
		if frameCount == 0 {
			rlottie_destroy(animationRef)
			return nil
		}
	}
	
	deinit {
		if let ref = ref {
			rlottie_destroy(ref)
		}
		pixelBuffer?.deallocate()
	}
	
//	deinit {
//		if let ref = ref {
//			rlottie_destroy(ref)
//		}
//	}
	
	public func render(frame index: Int, size: CGSize, scale: Double) -> UIImage? {
		guard let ref = ref else { return nil }


		let frame = state.currentFrame
		state.currentFrame = (state.currentFrame + 1) % state.frameCount

		let scale = UIScreen.main.scale
//		let scale = 2.0
		let width = Int(size.width * scale)
		let height = Int(size.height * scale)

		guard width > 0, height > 0 else { return nil }

		ensurePixelBuffer(width: width, height: height)

		guard let buffer = pixelBuffer else { return nil }

		rlottie_render_frame(
			ref,
			Int32(frame),
			buffer,
			Int32(width),
			Int32(height)
		)

		let data = Data(
			bytesNoCopy: buffer,
			count: pixelBufferSize,
			deallocator: .none
		)

		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}

		let cgImage = CGImage(
			width: width,
			height: height,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(
				rawValue:
					CGImageAlphaInfo.premultipliedFirst.rawValue |
					CGBitmapInfo.byteOrder32Little.rawValue
			),
			provider: provider,
			decode: nil,
			shouldInterpolate: true,
			intent: .defaultIntent
		)

		return cgImage.map { UIImage(cgImage: $0) }
	}
	
	private func ensurePixelBuffer(width: Int, height: Int) {
		let requiredSize = width * height * 4

		if pixelBufferSize < requiredSize ||
		   pixelBufferWidth != width ||
		   pixelBufferHeight != height {

			pixelBuffer?.deallocate()

			pixelBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: requiredSize)
			pixelBufferSize = requiredSize
			pixelBufferWidth = width
			pixelBufferHeight = height
		}
	}
	
//	public func renderNextFrame(size: CGSize) -> UIImage? {
//		guard let ref = ref else { return nil }
//		switch playbackMode {
//		case .once:
//			if state.currentFrame >= state.frameCount - 1 {
//				return nil
//			}
//		default:
//			break
//		}
//		let frame = state.currentFrame
//		state.currentFrame = (state.currentFrame + 1) % state.frameCount
////		self.state.currentFrame = (state.currentFrame + 1) % state.frameCount
//		let _scale = UIScreen.main.scale
//
//		let width = Int(size.width * _scale)
//		let height = Int(size.height * _scale)
//
//		guard width > 0 && height > 0 else { return nil }
//
//		let bufSize = width * height * 4
//
//		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
//		defer { buffer.deallocate() }
//
//		rlottie_render_frame(ref,
//							 Int32(self.state.currentFrame),
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
//			bitmapInfo: CGBitmapInfo(
//				rawValue:
//					CGImageAlphaInfo.premultipliedFirst.rawValue |
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
	
	public func resetAnimationStateToDefault() {
		state.currentFrame = 0
	}
}

//final class RLottieAnimation {
//	
//	var ref: UnsafeMutableRawPointer?
//	let frameCount: Int
//	
////	var fps: Int = 0
//	
//	init?(data: Data) {
//		var animationRef: UnsafeMutableRawPointer?
//		
//		data.withUnsafeBytes { bytes in
//			guard let baseAddress = bytes.baseAddress else { return }
//			let charPointer = baseAddress.assumingMemoryBound(to: CChar.self)
//			animationRef = rlottie_load_animation(charPointer, Int32(data.count))
//		}
//		
//		guard let animationRef = animationRef else { return nil }
//		self.ref = animationRef
//		self.frameCount = Int(rlottie_frame_count(animationRef))
//		
////		self.fps = Int(30)
//		
//		if frameCount == 0 {
//			rlottie_destroy(animationRef)
//			return nil
//		}
//	}
//	
//	deinit {
//		if let ref = ref {
//			rlottie_destroy(ref)
//		}
//	}
//	
//	func render(frame index: Int, size: CGSize, scale: Double) -> UIImage? {
//		guard let ref = ref else { return nil }
//		
////		let scale = 1.5
//		let _scale = UIScreen.main.scale
//		
//		let width = Int(size.width * _scale)
//		let height = Int(size.height * _scale)
//		
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

