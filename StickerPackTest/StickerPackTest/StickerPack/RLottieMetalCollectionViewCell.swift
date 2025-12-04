//
//  RLottieMetalCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import UIKit
import MetalKit
import Metal
import Compression
import zlib

class RLottieMetalCollectionViewCell: UICollectionViewCell {
	static let reuseIdentifier = "RLottieMetalCell"
	
	private var metalView: MTKView!
	private var renderer: RLottieMetalRenderer!
	private var animation: RLottieAnimation?
	private var displayLink: CADisplayLink?
	private var frameIndex = 0
	// Use a global serial queue to serialize all rlottie rendering (rlottie is not thread-safe)
	private static let globalRenderQueue = DispatchQueue(label: "com.rlottie.global.render", qos: .userInteractive)
	private var currentLoadTask: URLSessionDataTask?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupMetal()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupMetal() {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError("Metal is not supported")
		}
		
		metalView = MTKView(frame: bounds, device: device)
		metalView.translatesAutoresizingMaskIntoConstraints = false
		metalView.framebufferOnly = false
		metalView.enableSetNeedsDisplay = false
		metalView.isPaused = true
		metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
		
		renderer = RLottieMetalRenderer(device: device)
		metalView.delegate = renderer
		
		contentView.addSubview(metalView)
		NSLayoutConstraint.activate([
			metalView.topAnchor.constraint(equalTo: contentView.topAnchor),
			metalView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			metalView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			metalView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}
	
	func configure(with url: URL?) {
		stopAnimation()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		animation = nil
		
		guard let url = url else { return }
		
		// Check file extension to determine how to load
		let pathExtension = url.pathExtension.lowercased()
		
		if pathExtension == "tgs" {
			// .tgs files are gzipped JSON files (Telegram sticker format)
			loadTGSFile(from: url)
		} else if pathExtension == "json" || pathExtension.isEmpty {
			// Regular JSON Lottie files
			loadJSONFile(from: url)
		} else {
			print("Unsupported file type: \(pathExtension)")
		}
	}
	
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
			
			// Decompress gzipped data
			guard let jsonData = self.decompressGzip(data: compressedData) else {
				print("Failed to decompress TGS file")
				return
			}
			
			// Load animation from decompressed JSON
			DispatchQueue.main.async {
				self.loadAnimation(from: jsonData)
			}
		}
		
		currentLoadTask = task
		task.resume()
	}
	
	private func loadJSONFile(from url: URL) {
		if url.isFileURL {
			// Local file
			guard let data = try? Data(contentsOf: url) else {
				print("Failed to load local JSON file")
				return
			}
			loadAnimation(from: data)
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
		guard let anim = RLottieAnimation(data: data) else {
			print("Failed to create RLottieAnimation from data")
			return
		}
		
		self.animation = anim
		self.renderer.setAnimation(anim)
		self.frameIndex = 0
		startAnimation()
	}
	
	private func startAnimation() {
		stopAnimation()
		guard animation != nil else { return }
		
		displayLink = CADisplayLink(target: self, selector: #selector(tick))
		displayLink?.add(to: .main, forMode: .common)
		metalView.isPaused = false
	}
	
	private func stopAnimation() {
		displayLink?.invalidate()
		displayLink = nil
		metalView.isPaused = true
		frameIndex = 0
	}
	
	@objc private func tick() {
		guard let anim = animation else { return }
		
		frameIndex = (frameIndex + 1) % anim.frameCount
		
		// Render on background thread using global serial queue (rlottie is not thread-safe)
		let size = contentView.bounds.size
		guard size.width > 0 && size.height > 0 else { return }
		
		// Capture current frame index to avoid race condition
		let currentFrame = frameIndex
		
		Self.globalRenderQueue.async { [weak self] in
			guard let self = self,
				  let buffer = self.renderFrame(index: currentFrame, size: size) else { return }
			
			DispatchQueue.main.async {
				// Double-check animation still exists and frame hasn't changed too much
				guard self.animation != nil else {
					buffer.deallocate()
					return
				}
				self.renderer.updateTexture(with: buffer, size: size)
				self.metalView.draw()
			}
		}
	}
	
	private func renderFrame(index: Int, size: CGSize) -> UnsafeMutablePointer<UInt8>? {
		guard let ref = animation?.ref else { return nil }
		
		let width = Int(size.width * UIScreen.main.scale)
		let height = Int(size.height * UIScreen.main.scale)
		guard width > 0 && height > 0 else { return nil }
		
		let bufSize = width * height * 4
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
		
		// rlottie_render_frame must be called on the serial queue (already on it)
		// This ensures thread-safety since rlottie is not thread-safe
		rlottie_render_frame(ref, Int32(index), buffer, Int32(width), Int32(height))
		
		return buffer
	}
	
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
	
	override func prepareForReuse() {
		super.prepareForReuse()
		stopAnimation()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		animation = nil
	}
	
	override func didMoveToSuperview() {
		super.didMoveToSuperview()
		if superview == nil {
			stopAnimation()
		} else if animation != nil {
			startAnimation()
		}
	}
	
	deinit {
		stopAnimation()
	}
}

// Metal Renderer
class RLottieMetalRenderer: NSObject, MTKViewDelegate {
	private let device: MTLDevice
	private let commandQueue: MTLCommandQueue
	private var texture: MTLTexture?
	private var pipelineState: MTLRenderPipelineState?
	
	init(device: MTLDevice) {
		self.device = device
		guard let queue = device.makeCommandQueue() else {
			fatalError("Failed to create Metal command queue")
		}
		self.commandQueue = queue
		super.init()
		setupPipeline()
	}
	
	func setAnimation(_ animation: RLottieAnimation) {
		// Animation reference stored for rendering
	}
	
	func updateTexture(with buffer: UnsafeMutablePointer<UInt8>, size: CGSize) {
		let width = Int(size.width * UIScreen.main.scale)
		let height = Int(size.height * UIScreen.main.scale)
		
		// Reuse texture if size matches, otherwise create new one
		if let existingTexture = texture,
		   existingTexture.width == width,
		   existingTexture.height == height {
			// Reuse existing texture
			let region = MTLRegionMake2D(0, 0, width, height)
			let bytesPerRow = width * 4
			existingTexture.replace(region: region, mipmapLevel: 0, withBytes: buffer, bytesPerRow: bytesPerRow)
		} else {
			// Create new texture
			let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
				pixelFormat: .rgba8Unorm,
				width: width,
				height: height,
				mipmapped: false
			)
			textureDescriptor.usage = [.shaderRead]
			textureDescriptor.storageMode = .shared
			
			texture = device.makeTexture(descriptor: textureDescriptor)
			
			let region = MTLRegionMake2D(0, 0, width, height)
			let bytesPerRow = width * 4
			texture?.replace(region: region, mipmapLevel: 0, withBytes: buffer, bytesPerRow: bytesPerRow)
		}
		
		buffer.deallocate()
	}
	
	private func setupPipeline() {
		guard let library = device.makeDefaultLibrary() else {
			fatalError("Failed to create Metal library. Make sure Shaders.metal is included in the target.")
		}
		
		guard let vertexFunction = library.makeFunction(name: "vertex_main") else {
			fatalError("Failed to load vertex_main shader function")
		}
		
		guard let fragmentFunction = library.makeFunction(name: "fragment_main") else {
			fatalError("Failed to load fragment_main shader function")
		}
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = vertexFunction
		pipelineDescriptor.fragmentFunction = fragmentFunction
		pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		
		// Enable blending for transparency
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
		pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		
		do {
			pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		} catch {
			fatalError("Failed to create render pipeline state: \(error)")
		}
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// Handle size changes if needed
	}
	
	func draw(in view: MTKView) {
		guard let drawable = view.currentDrawable,
			  let pipelineState = pipelineState,
			  let texture = texture else {
			// If no texture yet, just clear the view
			if let drawable = view.currentDrawable {
				let commandBuffer = commandQueue.makeCommandBuffer()
				let renderPassDescriptor = MTLRenderPassDescriptor()
				renderPassDescriptor.colorAttachments[0].texture = drawable.texture
				renderPassDescriptor.colorAttachments[0].loadAction = .clear
				renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
				
				let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
				encoder?.endEncoding()
				commandBuffer?.present(drawable)
				commandBuffer?.commit()
			}
			return
		}
		
		guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
		
		let renderPassDescriptor = MTLRenderPassDescriptor()
		renderPassDescriptor.colorAttachments[0].texture = drawable.texture
		renderPassDescriptor.colorAttachments[0].loadAction = .clear
		renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
		
		guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
		
		encoder.setRenderPipelineState(pipelineState)
		encoder.setFragmentTexture(texture, index: 0)
		
		// Draw full-screen quad (4 vertices as triangle strip)
		// The vertex shader generates vertices procedurally based on vertex_id
		encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
		
		encoder.endEncoding()
		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}
