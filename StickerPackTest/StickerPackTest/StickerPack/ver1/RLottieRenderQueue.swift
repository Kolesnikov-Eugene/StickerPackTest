//
//  RLottieRenderQueue.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import Foundation
import UIKit

/// Global render queue manager for RLottie
/// RLottie is NOT thread-safe, so ALL rendering must happen on a single serial queue
/// This is critical for performance and correctness
final class RLottieRenderQueue {
	
	// MARK: - Singleton
	
	static let shared = RLottieRenderQueue()
	
	// MARK: - Properties
	
	/// Single global serial queue for ALL rlottie rendering operations
	/// This ensures thread-safety since rlottie is not thread-safe
	private let renderQueue: DispatchQueue
	
	/// Queue for managing render requests and priorities
	private let requestQueue: DispatchQueue
	
	/// Pending render requests
	private var pendingRequests: [RenderRequest] = []
	private var isProcessing = false
	
	// MARK: - Types
	
	private struct RenderRequest {
		let animationRef: UnsafeMutableRawPointer
		let frameIndex: Int32
		let buffer: UnsafeMutablePointer<UInt8>
		let width: Int32
		let height: Int32
		let completion: (Bool) -> Void
		let priority: Int // Lower = higher priority
	}
	
	// MARK: - Initialization
	
	private init() {
		// Single serial queue for all rlottie operations
		renderQueue = DispatchQueue(
			label: "com.rlottie.global.render",
			qos: .userInteractive
		)
		
		// Queue for managing requests
		requestQueue = DispatchQueue(
			label: "com.rlottie.request.manager",
			qos: .userInteractive
		)
	}
	
	// MARK: - Public API
	
	/// Render a frame synchronously (blocks until complete)
	/// Use sparingly - prefer async rendering
	func renderSync(
		animationRef: UnsafeMutableRawPointer,
		frameIndex: Int32,
		buffer: UnsafeMutablePointer<UInt8>,
		width: Int32,
		height: Int32
	) {
		renderQueue.sync {
			rlottie_render_frame(animationRef, frameIndex, buffer, width, height)
		}
	}
	
	/// Render a frame asynchronously
	func renderAsync(
		animationRef: UnsafeMutableRawPointer,
		frameIndex: Int32,
		buffer: UnsafeMutablePointer<UInt8>,
		width: Int32,
		height: Int32,
		priority: Int = 0,
		completion: @escaping (Bool) -> Void
	) {
		// For high priority (0), render directly without queuing to reduce latency
		// This bypasses the request queue for immediate rendering
		if priority == 0 {
			renderQueue.async { [animationRef, frameIndex, buffer, width, height] in
				rlottie_render_frame(animationRef, frameIndex, buffer, width, height)
				completion(true)
			}
			return
		}
		
		// For lower priority, use the queue system
		let request = RenderRequest(
			animationRef: animationRef,
			frameIndex: frameIndex,
			buffer: buffer,
			width: width,
			height: height,
			completion: completion,
			priority: priority
		)
		
		requestQueue.async { [weak self] in
			guard let self = self else {
				completion(false)
				return
			}
			
			// Limit queue size to prevent buildup
			if self.pendingRequests.count > 50 {
				// Remove oldest low-priority request
				if let lastIndex = self.pendingRequests.lastIndex(where: { $0.priority > 0 }) {
					self.pendingRequests[lastIndex].completion(false)
					self.pendingRequests.remove(at: lastIndex)
				}
			}
			
			// Add to pending requests (sorted by priority)
			self.pendingRequests.append(request)
			self.pendingRequests.sort { $0.priority < $1.priority }
			
			// Process if not already processing
			if !self.isProcessing {
				self.processNextRequest()
			}
		}
	}
	
	// MARK: - Private
	
	private func processNextRequest() {
		requestQueue.async { [weak self] in
			guard let self = self else { return }
			
			guard !self.pendingRequests.isEmpty else {
				self.isProcessing = false
				return
			}
			
			self.isProcessing = true
			let request = self.pendingRequests.removeFirst()
			
			// Execute render on serial queue
			self.renderQueue.async {
				rlottie_render_frame(
					request.animationRef,
					request.frameIndex,
					request.buffer,
					request.width,
					request.height
				)
				
				// Call completion
				request.completion(true)
				
				// Process next request
				self.requestQueue.async {
					self.processNextRequest()
				}
			}
		}
	}
	
	/// Cancel all pending requests (useful for cleanup)
	func cancelAllRequests() {
		requestQueue.async { [weak self] in
			guard let self = self else { return }
			
			// Complete all pending requests with failure
			for request in self.pendingRequests {
				request.completion(false)
			}
			self.pendingRequests.removeAll()
			self.isProcessing = false
		}
	}
}

