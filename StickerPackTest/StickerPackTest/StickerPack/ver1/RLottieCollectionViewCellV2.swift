//
//  RLottieCollectionViewCellV2.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import UIKit
import Compression
import zlib

/// Optimized RLottie collection view cell with proper threading and lifecycle management
/// Based on Telegram-iOS implementation patterns
class RLottieCollectionViewCellV2: UICollectionViewCell {
	
	static let reuseIdentifier = "RLottieCollectionViewCellV2"
	
	// MARK: - UI Components
	
	private let imageView: UIImageView = {
		let view = UIImageView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.contentMode = .scaleAspectFit
		view.clipsToBounds = true
		return view
	}()
	
	// MARK: - Animation Properties
	
	private var animation: RLottieAnimationV2?
	private var displayLink: CADisplayLink?
	private var currentFrameIndex = 0
	private var isPlaying = false
	private var isVisible = false
	
	// Rendering state
	private var currentRenderTask: DispatchWorkItem?
	private var lastRenderedFrame: Int = -1
	
	// Network loading
	private var currentLoadTask: URLSessionDataTask?
	
	// MARK: - Initialization
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupUI()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupUI() {
		backgroundColor = .systemGray6
		layer.cornerRadius = 8
		layer.masksToBounds = true
		
		contentView.addSubview(imageView)
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}
	
	// MARK: - Configuration
	
	func configure(with url: URL?) {
		// Clean up previous animation
		stopAnimation()
		cancelAllTasks()
		imageView.image = nil
		animation = nil
		currentFrameIndex = 0
		lastRenderedFrame = -1
		
		guard let url = url else { return }
		
		// Check file extension to determine how to load
		let pathExtension = url.pathExtension.lowercased()
		
		if pathExtension == "tgs" {
			loadTGSFile(from: url)
		} else if pathExtension == "json" || pathExtension.isEmpty {
			loadJSONFile(from: url)
		} else {
			print("Unsupported file type: \(pathExtension)")
		}
	}
	
	// MARK: - File Loading
	
	private func loadTGSFile(from url: URL) {
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self else { return }
			
			if let error = error {
				print("Error loading TGS file: \(error.localizedDescription)")
				return
			}
			
			guard let compressedData = data else {
				print("No data received for TGS file")
				return
			}
			
			// Decompress on background thread
			DispatchQueue.global(qos: .userInitiated).async {
				guard let jsonData = self.decompressGzip(data: compressedData) else {
					print("Failed to decompress TGS file")
					return
				}
				
				DispatchQueue.main.async {
					self.loadAnimation(from: jsonData)
				}
			}
		}
		
		currentLoadTask = task
		task.resume()
	}
	
	private func loadJSONFile(from url: URL) {
		if url.isFileURL {
			// Local file - load on background thread
			DispatchQueue.global(qos: .userInitiated).async { [weak self] in
				guard let self = self else { return }
				guard let data = try? Data(contentsOf: url) else {
					print("Failed to load local JSON file")
					return
				}
				DispatchQueue.main.async {
					self.loadAnimation(from: data)
				}
			}
		} else {
			// Remote URL
			let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
				guard let self = self else { return }
				
				if let error = error {
					print("Error loading JSON file: \(error.localizedDescription)")
					return
				}
				
				guard let jsonData = data else {
					print("No data received for JSON file")
					return
				}
				
				DispatchQueue.main.async {
					self.loadAnimation(from: jsonData)
				}
			}
			
			currentLoadTask = task
			task.resume()
		}
	}
	
	private func loadAnimation(from data: Data) {
		guard let anim = RLottieAnimationV2(data: data) else {
			print("Failed to create RLottieAnimationV2 from data")
			return
		}
		
		self.animation = anim
		self.currentFrameIndex = 0
		self.lastRenderedFrame = -1
		
		// Render first frame immediately
		renderCurrentFrame()
		
		// Start animation if visible
		if isVisible {
			startAnimation()
		}
	}
	
	// MARK: - Animation Control
	
	private func startAnimation() {
		guard !isPlaying else { return }
		guard animation != nil else { return }
		
		isPlaying = true
		
		// Use display link with appropriate frame interval
		displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
		displayLink?.preferredFramesPerSecond = 60
		displayLink?.add(to: .main, forMode: .common)
	}
	
	private func stopAnimation() {
		isPlaying = false
		displayLink?.invalidate()
		displayLink = nil
	}
	
	@objc private func displayLinkTick() {
		guard isPlaying, let anim = animation else {
			stopAnimation()
			return
		}
		
		// Simple frame increment - let display link handle timing
		currentFrameIndex = (currentFrameIndex + 1) % anim.frameCount
		
		// Only render if frame changed
		if currentFrameIndex != lastRenderedFrame {
			renderCurrentFrame()
		}
	}
	
	// MARK: - Frame Rendering
	
	private func renderCurrentFrame() {
		guard let anim = animation else { return }
		
		let size = contentView.bounds.size
		guard size.width > 0 && size.height > 0 else {
			// Use default size if bounds not ready
			let defaultSize = CGSize(width: 256, height: 256)
			renderFrame(index: currentFrameIndex, size: defaultSize)
			return
		}
		
		renderFrame(index: currentFrameIndex, size: size)
	}
	
	private func renderFrame(index: Int, size: CGSize) {
		guard let anim = animation else { return }
		
		// Cancel any pending render task
		currentRenderTask?.cancel()
		
		// Update last rendered frame
		lastRenderedFrame = index
		
		// Render directly without extra dispatch - the renderAsync already handles threading
		anim.renderAsync(frame: index, size: size, priority: 0) { [weak self] image in
			guard let self = self else { return }
			
			// Double-check we still need this frame
			guard index == self.currentFrameIndex else { return }
			
			// Update image on main thread (already on main from renderAsync)
			self.imageView.image = image
		}
	}
	
	// MARK: - Gzip Decompression
	
	/// Decompresses gzipped data (for .tgs files)
	private func decompressGzip(data: Data) -> Data? {
		guard !data.isEmpty else { return nil }
		
		// Check for gzip magic number (1f 8b)
		guard data.count >= 2 else { return nil }
		let magic = data.withUnsafeBytes { $0.load(as: UInt16.self) }
		guard magic == 0x8b1f || magic == 0x1f8b else {
			return nil
		}
		
		var inputData = data
		return inputData.withUnsafeMutableBytes { (inputBytes: UnsafeMutableRawBufferPointer) in
			guard let inputBase = inputBytes.baseAddress else { return nil }
			
			var stream = z_stream()
			var result = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
			guard result == Z_OK else { return nil }
			defer { inflateEnd(&stream) }
			
			var decompressed = Data()
			let bufferSize = 4096
			var buffer = [UInt8](repeating: 0, count: bufferSize)
			
			stream.next_in = inputBase.assumingMemoryBound(to: UInt8.self)
			stream.avail_in = UInt32(data.count)
			
			repeat {
				stream.next_out = buffer.withUnsafeMutableBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
				stream.avail_out = UInt32(bufferSize)
				
				result = inflate(&stream, Z_SYNC_FLUSH)
				
				guard result == Z_OK || result == Z_STREAM_END else {
					return nil
				}
				
				let written = bufferSize - Int(stream.avail_out)
				if written > 0 {
					decompressed.append(contentsOf: buffer.prefix(written))
				}
			} while stream.avail_out == 0 && result != Z_STREAM_END
			
			return result == Z_STREAM_END ? decompressed : nil
		}
	}
	
	// MARK: - Task Management
	
	private func cancelAllTasks() {
		currentLoadTask?.cancel()
		currentLoadTask = nil
		currentRenderTask?.cancel()
		currentRenderTask = nil
	}
	
	// MARK: - Lifecycle
	
	override func prepareForReuse() {
		super.prepareForReuse()
		stopAnimation()
		cancelAllTasks()
		imageView.image = nil
		animation = nil
		currentFrameIndex = 0
		lastRenderedFrame = -1
		isVisible = false
	}
	
	override func didMoveToSuperview() {
		super.didMoveToSuperview()
		
		if superview == nil {
			// Removed from view hierarchy - stop animation
			isVisible = false
			stopAnimation()
		} else {
			// Added to view hierarchy
			isVisible = true
			if animation != nil {
				startAnimation()
			}
		}
	}
	
	override func willMove(toSuperview newSuperview: UIView?) {
		super.willMove(toSuperview: newSuperview)
		
		if newSuperview == nil {
			// About to be removed - stop animation early
			isVisible = false
			stopAnimation()
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		// Re-render current frame if size changed
		if animation != nil && contentView.bounds.size.width > 0 && contentView.bounds.size.height > 0 {
			renderCurrentFrame()
		}
	}
	
	deinit {
		stopAnimation()
		cancelAllTasks()
	}
}
