//
//  RLottiePlayer.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import Foundation
import UIKit

final class RLottiePlayer {
	private let animation: RLottieAnimationFast
	private weak var imageView: UIImageView?
	
	private let renderQueue = DispatchQueue(label: "com.rlottie.render.fast", qos: .userInitiated)
	private var displayLink: CADisplayLink?
	
	private var frameCount: Int
	private var currentFrame = 0
	
	private let width: Int
	private let height: Int
	
	private let buffer: UnsafeMutablePointer<UInt8>
	
	private let fps: Int
	private var frameAccumulator: CFTimeInterval = 0

	init?(animation: RLottieAnimationFast,
		  imageView: UIImageView,
		  maxDimension: CGFloat = 512,
		  preferredFPS: Int? = nil)
	{
		self.animation = animation
		self.imageView = imageView
		
		self.frameCount = animation.frameCount
		
		self.fps = preferredFPS ?? 60

		// --- FIX: Compute render size once ONCE on main thread ---
		let size = imageView.bounds.size
		let scale = min(maxDimension / max(size.width, size.height), 1.0)
		let w = max(1, Int(size.width * scale))
		let h = max(1, Int(size.height * scale))
		print("h is \(w) - \(h)")
		self.width = w * 2
		self.height = h * 2
		
		buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h * 4 * 4)
	}

	// MARK: - Playback

	func start() {
		stop()

		let dl = CADisplayLink(target: self, selector: #selector(tick))
		dl.add(to: .main, forMode: .common)
		displayLink = dl
	}

	func stop() {
		displayLink?.invalidate()
		displayLink = nil
	}

	@objc private func tick(_ link: CADisplayLink) {
		frameAccumulator += link.duration
		let frameDuration = 1.0 / Double(fps)
		
		// Skip until enough time passed
		if frameAccumulator < frameDuration { return }
		frameAccumulator -= frameDuration

		let frame = currentFrame
		currentFrame = (currentFrame + 1) % frameCount

		renderFrame(frame)
	}

	private func renderFrame(_ frame: Int) {
		renderQueue.async { [weak self] in
			guard let self else { return }
			
			rlottie_render_frame(self.animation.ref,
								 Int32(frame),
								 self.buffer,
								 Int32(self.width),
								 Int32(self.height))
			
			guard let cgImage = Self.makeImage(buf: self.buffer, w: self.width, h: self.height) else { return }
			
			DispatchQueue.main.async {
				self.imageView?.image = UIImage(cgImage: cgImage)
			}
		}
	}

	// MARK: - Image Conversion

	private static func makeImage(buf: UnsafeMutablePointer<UInt8>,
								  w: Int,
								  h: Int) -> CGImage?
	{
		let bytesPerRow = w * 4
		let cs = CGColorSpaceCreateDeviceRGB()
		
		guard let ctx = CGContext(
			data: buf,
			width: w,
			height: h,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: cs,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		return ctx.makeImage()
	}

	deinit {
		stop()
		buffer.deallocate()
	}
}

//final class RLottiePlayer {
//	private let animation: RLottieAnimationFast
//	private weak var imageView: UIImageView?
//	private let maxDimension: Int
//	private let preferredFPS: Int? // optional limiter; if nil use animation frameRate if you expose it
//	private var displayLink: CADisplayLink?
//	private var lastTimestamp: CFTimeInterval = 0
//	private var frameIndex: Int = 0
//	private var isPlaying = false
//	private let deviceScale: Int = Int(UIScreen.main.scale)
//	private let renderQueue = DispatchQueue(label: "com.yourapp.rlottie.player", qos: .userInitiated)
//
//	// simple frame cache
//	private let frameCache = NSCache<NSNumber, UIImage>()
//	private let cacheLimit: Int = 40
//
//	init(animation: RLottieAnimationFast, imageView: UIImageView, maxDimension: Int = 320, preferredFPS: Int? = nil) {
//		self.animation = animation
//		self.imageView = imageView
//		self.maxDimension = maxDimension
//		self.preferredFPS = preferredFPS
//		frameCache.countLimit = cacheLimit
//	}
//
//	func start() {
//		stop()
//		isPlaying = true
//		frameIndex = 0
//		lastTimestamp = 0
//
//		// render first frame immediately
//		renderFrame(index: frameIndex)
//
//		let link = CADisplayLink(target: self, selector: #selector(displayTick(_:)))
//		// set preferredFramesPerSecond if needed
//		if let pf = preferredFPS {
//			link.preferredFramesPerSecond = pf
//		} else {
//			// fallback: use 30fps (you can adjust or expose animation frameRate if available)
//			link.preferredFramesPerSecond = 30
//		}
//		link.add(to: .main, forMode: .common)
//		self.displayLink = link
//	}
//
//	func stop() {
//		isPlaying = false
//		displayLink?.invalidate()
//		displayLink = nil
//	}
//
//	@objc private func displayTick(_ link: CADisplayLink) {
//		guard isPlaying else { return }
//
//		// compute next frame index
//		// we simply increment modulo frameCount — advanced timing could map timestamps to frame numbers
//		frameIndex = (frameIndex + 1) % animation.frameCount
//
//		// check cache first
//		let key = NSNumber(value: frameIndex)
//		if let cached = frameCache.object(forKey: key) {
//			imageView?.image = cached
//			return
//		}
//
//		renderFrame(index: frameIndex)
//	}
//
//	private func renderFrame(index: Int) {
//		guard let imageView = imageView else { return }
//
//		// Compute display size in points and clamp to maxDimension
//		let viewSizePoints = imageView.bounds.size
//		guard viewSizePoints.width > 0 && viewSizePoints.height > 0 else { return }
//
//		// Determine target render pixel size:
//		// Prefer animation intrinsic size (if smaller than max) otherwise clamp to maxDimension.
//		var animW = animation.intrinsicWidth
//		var animH = animation.intrinsicHeight
//		if animW <= 0 || animH <= 0 {
//			// No intrinsic size — use view size
//			animW = Int(viewSizePoints.width)
//			animH = Int(viewSizePoints.height)
//		}
//
//		// Scale down to maxDimension preserving aspect ratio
//		let maxDim = CGFloat(maxDimension)
//		let scaleFactor = min(1.0, min(maxDim / CGFloat(animW), maxDim / CGFloat(animH)))
//		let scaledWPoints = CGFloat(animW) * scaleFactor
//		let scaledHPoints = CGFloat(animH) * scaleFactor
//
//		// Multiply by device scale for pixel size
//		let pixelW = max(1, Int(round(scaledWPoints * CGFloat(deviceScale))))
//		let pixelH = max(1, Int(round(scaledHPoints * CGFloat(deviceScale))))
//
//		let renderSizePixels = CGSize(width: pixelW, height: pixelH)
//
//		// ask animation to render asynchronously
//		animation.renderAsync(frame: index, renderPixelSize: renderSizePixels, scale: deviceScale) { [weak self] image in
//			guard let self = self, let image = image else { return }
//			// cache image
//			self.frameCache.setObject(image, forKey: NSNumber(value: index))
//			self.imageView?.image = image
//		}
//	}
//}
