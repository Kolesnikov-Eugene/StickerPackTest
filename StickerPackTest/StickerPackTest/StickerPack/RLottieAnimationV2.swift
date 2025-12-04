//
//  RLottieAnimationV2.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import Foundation
import UIKit

/// Improved RLottie animation wrapper with optimized rendering
/// Based on Telegram-iOS implementation patterns
final class RLottieAnimationV2 {
	
	// MARK: - Properties
	
	var ref: UnsafeMutableRawPointer?
	let frameCount: Int
	let intrinsicSize: CGSize
	
	// Simple flag to prevent new renders after deallocation starts
	// The C++ side handles safety by copying the shared_ptr
	private var isDestroyed: Bool = false
	private let destroyedLock = NSLock()
	
	// MARK: - Initialization
	
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
		
		if frameCount == 0 {
			rlottie_destroy(animationRef)
			return nil
		}
		
		// Default size for Telegram stickers
		self.intrinsicSize = CGSize(width: 512, height: 512)
	}
	
	deinit {
		// Mark as destroyed to prevent new renders
		destroyedLock.lock()
		isDestroyed = true
		destroyedLock.unlock()
		
		// Destroy immediately - the C++ side handles safety by copying shared_ptr
		// This prevents blocking and delays
		if let ref = ref {
			rlottie_destroy(ref)
		}
	}
	
	// MARK: - Frame Rendering
	
	/// Render a frame synchronously (for immediate use)
	func render(frame index: Int, size: CGSize) -> UIImage? {
		// Quick check if destroyed
		destroyedLock.lock()
		let destroyed = isDestroyed
		let ref = self.ref
		destroyedLock.unlock()
		
		guard !destroyed, let ref = ref else { return nil }
		guard index >= 0 && index < frameCount else { return nil }
		
		let scale = UIScreen.main.scale
		let width = Int(size.width * scale)
		let height = Int(size.height * scale)
		
		guard width > 0 && height > 0 else { return nil }
		
		// Allocate buffer
		let bufSize = width * height * 4
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
		defer { buffer.deallocate() }
		
		// Render using global queue
		RLottieRenderQueue.shared.renderSync(
			animationRef: ref,
			frameIndex: Int32(index),
			buffer: buffer,
			width: Int32(width),
			height: Int32(height)
		)
		
		// Create UIImage from buffer
		return createImage(from: buffer, width: width, height: height)
	}
	
	/// Render a frame asynchronously (for background rendering)
	func renderAsync(
		frame index: Int,
		size: CGSize,
		priority: Int = 0,
		completion: @escaping (UIImage?) -> Void
	) {
		// Quick check if destroyed
		destroyedLock.lock()
		let destroyed = isDestroyed
		let ref = self.ref
		destroyedLock.unlock()
		
		guard !destroyed, let ref = ref else {
			DispatchQueue.main.async { completion(nil) }
			return
		}
		
		guard index >= 0 && index < frameCount else {
			DispatchQueue.main.async { completion(nil) }
			return
		}
		
		let scale = UIScreen.main.scale
		let width = Int(size.width * scale)
		let height = Int(size.height * scale)
		
		guard width > 0 && height > 0 else {
			DispatchQueue.main.async { completion(nil) }
			return
		}
		
		// Allocate buffer
		let bufSize = width * height * 4
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
		
		// Render asynchronously using global queue
		RLottieRenderQueue.shared.renderAsync(
			animationRef: ref,
			frameIndex: Int32(index),
			buffer: buffer,
			width: Int32(width),
			height: Int32(height),
			priority: priority
		) { success in
			defer { buffer.deallocate() }
			
			guard success else {
				DispatchQueue.main.async { completion(nil) }
				return
			}
			
			// Create UIImage from buffer
			let image = self.createImage(from: buffer, width: width, height: height)
			DispatchQueue.main.async { completion(image) }
		}
	}
	
	// MARK: - Private Helpers
	
	private func createImage(from buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) -> UIImage? {
		let bufSize = width * height * 4
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
		
		guard let cgImage = cgImage else { return nil }
		return UIImage(cgImage: cgImage)
	}
}
