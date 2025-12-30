//
//  SharedDisplayLink.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 17.12.2025.
//

import UIKit

public class SharedDisplayLinkAnimator {
	
	public static let shared = SharedDisplayLinkAnimator()
	
	private var displayLink: CADisplayLink?
	private var subscribers = NSHashTable<RLottieCollectionViewCell>.weakObjects()
	
	private var lastTick: CFTimeInterval = 0
	public var targetFPS: Double = 120
	
	private init() {}
	
	// MARK: - Subscription
	
	func add(_ view: RLottieCollectionViewCell) {
		subscribers.add(view)
		startIfNeeded()
	}
	
	func remove(_ view: RLottieCollectionViewCell) {
		subscribers.remove(view)
		stopIfNeeded()
	}
	
	// MARK: - DisplayLink
	
	private func startIfNeeded() {
		guard displayLink == nil else { return }
		
		lastTick = CACurrentMediaTime()
		let link = CADisplayLink(target: self, selector: #selector(tick))
		link.preferredFrameRateRange = CAFrameRateRange(
			minimum: 30,
			maximum: 60,
			preferred: 60
		)
		link.add(to: .main, forMode: .common)
		displayLink = link
	}
	
	private func stopIfNeeded() {
		if subscribers.allObjects.isEmpty {
			print("........ invalidating display link")
			displayLink?.invalidate()
			displayLink = nil
		}
	}
	
	@objc
	private func tick() {
//		let now = CACurrentMediaTime()
//		let minDelta = 1.0 / targetFPS
//
//		guard now - lastTick >= minDelta else { return }
//		lastTick = now
		
		for view in subscribers.allObjects {
			view._tickerTick()
		}
	}
}
