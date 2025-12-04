//
//  RLottieAnimationFast.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import Foundation
import UIKit

final class RLottieAnimationFast {
	private(set) var ref: UnsafeMutableRawPointer?
	let frameCount: Int
	private(set) var intrinsicWidth: Int
	private(set) var intrinsicHeight: Int

	// Buffer reuse
	private var renderBuffer: UnsafeMutablePointer<UInt8>?
	private var renderBufferSize: Int = 0
	private var currentRenderWidth: Int = 0
	private var currentRenderHeight: Int = 0

	// rendering queue (serial) - single threaded rendering per animation
	private let renderQueue = DispatchQueue(label: "com.yourapp.rlottie.render", qos: .userInitiated)

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

		// fetch intrinsic size (rlottie bridge should provide these functions if you added them)
//		if  {
//			
//		} else {
//			self.intrinsicWidth = 0
//			self.intrinsicHeight = 0
//		}
		let r = animationRef
		self.intrinsicWidth = Int(rlottie_animation_width(r))
		self.intrinsicHeight = Int(rlottie_animation_height(r))

		if frameCount == 0 {
			rlottie_destroy(animationRef)
			return nil
		}
	}

	deinit {
		renderBuffer?.deallocate()
		if let r = ref {
			rlottie_destroy(r)
		}
	}

	/// Render a frame synchronously but off main thread. Call from background queue.
	/// - Parameters:
	///   - index: frame index
	///   - targetPixelSize: size in pixels (width,height) — not points
	/// - Returns: UIImage (with correct scale) or nil
	func renderSyncOnCurrentThread(frame index: Int, pixelSize targetPixelSize: CGSize, scale: Int) -> UIImage? {
		guard let ref = ref else { return nil }

		let targetW = max(1, Int(targetPixelSize.width))
		let targetH = max(1, Int(targetPixelSize.height))
		let bufSize = targetW * targetH * 4

		print("target width - height - \(targetW) - \(targetH)")
		// reuse buffer if possible; reallocate if needed
		if renderBufferSize < bufSize || currentRenderWidth != targetW || currentRenderHeight != targetH {
			renderBuffer?.deallocate()
			renderBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
			renderBufferSize = bufSize
			currentRenderWidth = targetW
			currentRenderHeight = targetH
		}
		guard let buffer = renderBuffer else { return nil }
		
		print("target width - height - \(targetW) - \(targetH)")

		// call rlottie C wrapper (fast native rendering)
		rlottie_render_frame(ref, Int32(index), buffer, Int32(targetW), Int32(targetH))

		// create CGImage from BGRA premultiplied little-endian buffer
		let data = Data(bytesNoCopy: buffer, count: bufSize, deallocator: .none)
		guard let provider = CGDataProvider(data: data as CFData) else { return nil }

		let bitmapInfo = CGBitmapInfo(rawValue:
			CGImageAlphaInfo.premultipliedFirst.rawValue |
			CGBitmapInfo.byteOrder32Little.rawValue
		)

		guard let cgImage = CGImage(
			width: targetW,
			height: targetH,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: targetW * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: bitmapInfo,
			provider: provider,
			decode: nil,
			shouldInterpolate: true,
			intent: .defaultIntent
		) else { return nil }

		// Return UIImage with the proper scale (so UIKit displays it correctly)
		return UIImage(cgImage: cgImage, scale: CGFloat(scale), orientation: .up)
	}

	/// Async render API - executes rendering on the internal renderQueue and calls completion on main thread.
	/// - Parameters:
	///   - index: frame index
	///   - renderPixelSize: requested pixel size (width,height). Use intrinsic size * scale or capped size.
	///   - scale: device scale (1,2,3)
	func renderAsync(frame index: Int, renderPixelSize: CGSize, scale: Int, completion: @escaping (UIImage?) -> Void) {
		// Ensure rendering runs on renderQueue
		renderQueue.async { [weak self] in
			guard let self = self else {
				DispatchQueue.main.async { completion(nil) }
				return
			}
			let img = self.renderSyncOnCurrentThread(frame: index, pixelSize: renderPixelSize, scale: scale)
			DispatchQueue.main.async {
				completion(img)
			}
		}
	}
}
