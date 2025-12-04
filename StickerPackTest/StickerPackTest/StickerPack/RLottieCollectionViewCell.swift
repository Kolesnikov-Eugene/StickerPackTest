//
//  RLottieCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//

import UIKit
import Compression
import zlib

class RLottieCollectionViewCell: UICollectionViewCell {
	
	static let reuseIdentifier = "RLottieCollectionViewCell"
	
	private let imageView: UIImageView = {
		let view = UIImageView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.contentMode = .scaleAspectFit
		view.clipsToBounds = true
		return view
	}()
	
	private var animation: RLottieAnimation?
	private var displayLink: CADisplayLink?
	private var frameIndex = 0
	private var currentLoadTask: URLSessionDataTask?
	
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
	
	func configure(with url: URL?) {
		// Clean up previous animation
		stopAnimation()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		imageView.image = nil
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
		self.frameIndex = 0
		startAnimation()
	}
	
	private func startAnimation() {
		stopAnimation()
		
		guard animation != nil else { return }
		
		// Render first frame
		tick()
		
		displayLink = CADisplayLink(target: self, selector: #selector(tick))
		displayLink?.add(to: .main, forMode: .common)
	}
	
	private func stopAnimation() {
		displayLink?.invalidate()
		displayLink = nil
		frameIndex = 0
	}
	
	@objc private func tick() {
		guard let anim = animation else { return }
		
		frameIndex = (frameIndex + 1) % anim.frameCount
		
		let size = contentView.bounds.size
		guard size.width > 0 && size.height > 0 else {
			// If size is zero, use a default size
			let defaultSize = CGSize(width: 256, height: 256)
			if let image = anim.render(frame: frameIndex, size: defaultSize) {
				imageView.image = image
			}
			return
		}
		
		if let image = anim.render(frame: frameIndex, size: size) {
			imageView.image = image
		}
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
		imageView.image = nil
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

//class RLottieCollectionViewCell: UICollectionViewCell {
//    
//    static let reuseIdentifier = "RLottieCollectionViewCell"
//    
//    private let imageView: UIImageView = {
//        let view = UIImageView()
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.contentMode = .scaleAspectFit
//        view.clipsToBounds = true
//        return view
//    }()
//    
//    private var animation: RLottieAnimation?
//    private var displayLink: CADisplayLink?
//    private var frameIndex = 0
//    private var currentLoadTask: URLSessionDataTask?
//    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupUI()
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    private func setupUI() {
//        backgroundColor = .systemGray6
//        layer.cornerRadius = 8
//        layer.masksToBounds = true
//        
//        contentView.addSubview(imageView)
//        
//        NSLayoutConstraint.activate([
//            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
//            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
//            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
//        ])
//    }
//    
//    func configure(with url: URL?) {
//        // Clean up previous animation
//        stopAnimation()
//        currentLoadTask?.cancel()
//        currentLoadTask = nil
//        imageView.image = nil
//        animation = nil
//        
//        guard let url = url else { return }
//        
//        // Check file extension to determine how to load
//        let pathExtension = url.pathExtension.lowercased()
//        
//        if pathExtension == "tgs" {
//            // .tgs files are gzipped JSON files (Telegram sticker format)
//            loadTGSFile(from: url)
//        } else if pathExtension == "json" || pathExtension.isEmpty {
//            // Regular JSON Lottie files
//            loadJSONFile(from: url)
//        } else {
//            print("Unsupported file type: \(pathExtension)")
//        }
//    }
//    
//    private func loadTGSFile(from url: URL) {
//        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                print("Error loading TGS file: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let compressedData = data else {
//                print("No data received for TGS file")
//                return
//            }
//            
//            // Decompress gzipped data
//            guard let jsonData = self.decompressGzip(data: compressedData) else {
//                print("Failed to decompress TGS file")
//                return
//            }
//            
//            // Load animation from decompressed JSON
//            DispatchQueue.main.async {
//                self.loadAnimation(from: jsonData)
//            }
//        }
//        
//        currentLoadTask = task
//        task.resume()
//    }
//    
//    private func loadJSONFile(from url: URL) {
//        if url.isFileURL {
//            // Local file
//            guard let data = try? Data(contentsOf: url) else {
//                print("Failed to load local JSON file")
//                return
//            }
//            loadAnimation(from: data)
//        } else {
//            // Remote URL
//            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
//                guard let self = self else { return }
//                
//                if let error = error {
//                    print("Error loading JSON file: \(error.localizedDescription)")
//                    return
//                }
//                
//                guard let jsonData = data else {
//                    print("No data received for JSON file")
//                    return
//                }
//                
//                DispatchQueue.main.async {
//                    self.loadAnimation(from: jsonData)
//                }
//            }
//            
//            currentLoadTask = task
//            task.resume()
//        }
//    }
//    
//    private func loadAnimation(from data: Data) {
//        guard let anim = RLottieAnimation(data: data) else {
//            print("Failed to create RLottieAnimation from data")
//            return
//        }
//        
//        self.animation = anim
//        self.frameIndex = 0
//        startAnimation()
//    }
//    
//    private func startAnimation() {
//        stopAnimation()
//        
//        guard animation != nil else { return }
//        
//        // Render first frame
//        tick()
//        
//        displayLink = CADisplayLink(target: self, selector: #selector(tick))
//        displayLink?.add(to: .main, forMode: .common)
//    }
//    
//    private func stopAnimation() {
//        displayLink?.invalidate()
//        displayLink = nil
//        frameIndex = 0
//    }
//    
//    @objc private func tick() {
//        guard let anim = animation else { return }
//        
//        frameIndex = (frameIndex + 1) % anim.frameCount
//        
//        let size = contentView.bounds.size
//        guard size.width > 0 && size.height > 0 else {
//            // If size is zero, use a default size
//            let defaultSize = CGSize(width: 256, height: 256)
//            if let image = anim.render(frame: frameIndex, size: defaultSize) {
//                imageView.image = image
//            }
//            return
//        }
//        
//        if let image = anim.render(frame: frameIndex, size: size) {
//            imageView.image = image
//        }
//    }
//    
//    /// Decompresses gzipped data (for .tgs files)
//    private func decompressGzip(data: Data) -> Data? {
//        guard !data.isEmpty else { return nil }
//        
//        // Check for gzip magic number (1f 8b)
//        guard data.count >= 2 else { return nil }
//        let magic = data.withUnsafeBytes { $0.load(as: UInt16.self) }
//        guard magic == 0x8b1f || magic == 0x1f8b else {
//            return nil
//        }
//        
//        var inputData = data
//        return inputData.withUnsafeMutableBytes { (inputBytes: UnsafeMutableRawBufferPointer) in
//            guard let inputBase = inputBytes.baseAddress else { return nil }
//            
//            var stream = z_stream()
//            var result = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
//            guard result == Z_OK else { return nil }
//            defer { inflateEnd(&stream) }
//            
//            var decompressed = Data()
//            let bufferSize = 4096
//            var buffer = [UInt8](repeating: 0, count: bufferSize)
//            
//            stream.next_in = inputBase.assumingMemoryBound(to: UInt8.self)
//            stream.avail_in = UInt32(data.count)
//            
//            repeat {
//                stream.next_out = buffer.withUnsafeMutableBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
//                stream.avail_out = UInt32(bufferSize)
//                
//                result = inflate(&stream, Z_SYNC_FLUSH)
//                
//                guard result == Z_OK || result == Z_STREAM_END else {
//                    return nil
//                }
//                
//                let written = bufferSize - Int(stream.avail_out)
//                if written > 0 {
//                    decompressed.append(contentsOf: buffer.prefix(written))
//                }
//            } while stream.avail_out == 0 && result != Z_STREAM_END
//            
//            return result == Z_STREAM_END ? decompressed : nil
//        }
//    }
//    
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        stopAnimation()
//        currentLoadTask?.cancel()
//        currentLoadTask = nil
//        imageView.image = nil
//        animation = nil
//    }
//    
//    override func didMoveToSuperview() {
//        super.didMoveToSuperview()
//        if superview == nil {
//            stopAnimation()
//        } else if animation != nil {
//            startAnimation()
//        }
//    }
//    
//    deinit {
//        stopAnimation()
//    }
//}
