//
//  SPLottieCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 02.12.2025.
//

import UIKit
import Lottie
import Foundation // Required for URLSession
import Compression
import zlib
// Note: You must ensure you have a library or extension for gzip decompression.
// The code below assumes you have access to a function like Data.gunzipped()

// --- LottieAnimationCache.swift ---
final class LottieAnimationCache {
	// Cache stores LottieAnimation objects using their URL as the key
	private let cache = NSCache<NSURL, LottieAnimation>()

	func getAnimation(for url: URL) -> LottieAnimation? {
		return cache.object(forKey: url as NSURL)
	}

	func setAnimation(_ animation: LottieAnimation, for url: URL) {
		cache.setObject(animation, forKey: url as NSURL)
	}
}
 // This is needed for the gunzipped() function

// MARK: - Gzip Decompression (Assumed Helper)
// You need a concrete implementation for this to compile.
// If using the zlib-based Compression framework:


// --- Modified SPLottieCollectionViewCell.swift ---
class SPLottieCollectionViewCell: UICollectionViewCell {
	
	static let reuseIdentifier = "SPLottieCollectionViewCell"
	
	// The LottieAnimationView is configured to loop and scale
	let animationView: LottieAnimationView = {
		let view = LottieAnimationView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.contentMode = .scaleAspectFit
		view.loopMode = .loop
		// Core Animation renderer is default for Lottie 4.5.2,
		// but can be explicitly set if needed:
		// view.rendererType = .coreAnimation
		return view
	}()
	
	private var currentLoadTask: URLSessionDataTask?
	private var currentURL: URL? // Store the URL for caching and reference
	private weak var cache: LottieAnimationCache? // Dependency for caching
	
	// MARK: - Setup (Unchanged)
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
		contentView.addSubview(animationView)
		
		NSLayoutConstraint.activate([
			animationView.topAnchor.constraint(equalTo: contentView.topAnchor),
			animationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			animationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			animationView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}
	
	// MARK: - Public Configuration API
	
	/// Configures the cell, checking the cache first before loading.
	func configure(with url: URL?, cache: LottieAnimationCache) {
		// 1. Cancel previous operations
		currentLoadTask?.cancel()
		currentLoadTask = nil
		animationView.animation = nil
		
		guard let url = url else { return }
		self.currentURL = url
		self.cache = cache
		
		// 2. CHECK CACHE (The main optimization)
		if let cachedAnimation = cache.getAnimation(for: url) {
			// Found in cache! Set animation and start (will be stopped/played by VC)
			self.animationView.animation = cachedAnimation
			// The VC's willDisplayCell method will call startAnimation()
			return
		}
		
		// 3. Load if not in cache
		let pathExtension = url.pathExtension.lowercased()
		
		if pathExtension == "tgs" {
			loadTGSFile(from: url)
		} else if pathExtension == "json" || pathExtension.isEmpty {
			loadJSONFile(from: url)
		} else {
			print("Unsupported file type: \(pathExtension)")
		}
	}
	
	// MARK: - Loading Logic (Modified)
	
	private func loadTGSFile(from url: URL) {
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self, self.currentURL == url else { return }
			
			if let error = error {
				print("Error loading TGS file: \(error.localizedDescription)")
				return
			}
			
			guard let compressedData = data else {
				print("No data received for TGS file")
				return
			}
			
			// Decompress gzipped data (CPU heavy, done on background queue)
			guard let jsonData = compressedData.gunzipped() else {
				print("Failed to decompress TGS file")
				return
			}
			
			// Create Lottie animation from decompressed JSON (Still CPU heavy, but off-main)
			do {
				let animation = try LottieAnimation.from(data: jsonData)
				
				// Dispatch final UI update and caching to main thread
				DispatchQueue.main.async {
					// Check again if we're still configured for this URL
					guard self.currentURL == url else { return }
					
					self.cache?.setAnimation(animation, for: url) // Caching success!
					self.animationView.animation = animation
					// The VC will call self.startAnimation() when cell is visible
				}
			} catch {
				print("Error creating Lottie animation from TGS: \(error.localizedDescription)")
			}
		}
		
		currentLoadTask = task
		task.resume()
	}
	
	private func loadJSONFile(from url: URL) {
		// Use the same logic as TGS for remote JSON to handle caching
		guard !url.isFileURL else {
			// Local file load (less common for stickers, keep it simple)
			animationView.animation = LottieAnimation.filepath(url.path)
			return
		}
		
		// Remote URL load
		loadJSONFromURL(url)
	}
	
	private func loadJSONFromURL(_ url: URL) {
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self, self.currentURL == url else { return }
			
			if let error = error {
				print("Error loading JSON file: \(error.localizedDescription)")
				return
			}
			
			guard let jsonData = data else {
				print("No data received for JSON file")
				return
			}
			
			// Create Lottie animation from JSON (Still CPU heavy, but off-main)
			do {
				let animation = try LottieAnimation.from(data: jsonData)
				
				// Dispatch final UI update and caching to main thread
				DispatchQueue.main.async {
					// Check again if we're still configured for this URL
					guard self.currentURL == url else { return }
					
					self.cache?.setAnimation(animation, for: url) // Caching success!
					self.animationView.animation = animation
					// The VC will call self.startAnimation() when cell is visible
				}
			} catch {
				print("Error creating Lottie animation from JSON: \(error.localizedDescription)")
			}
		}
		
		currentLoadTask = task
		task.resume()
	}
	
	// MARK: - Animation Control APIs
	
	/// Public API for VC to start the animation when visible.
	func startAnimation() {
		if animationView.animation != nil && !animationView.isAnimationPlaying {
			animationView.play()
		}
	}
	
	/// Public API for VC to stop the animation when off-screen.
	func stopAnimation() {
		animationView.stop()
	}
	
	// MARK: - Reuse
	
	override func prepareForReuse() {
		super.prepareForReuse()
		// Cancel ongoing tasks
		currentLoadTask?.cancel()
		currentLoadTask = nil
		currentURL = nil
		
		// Stop and remove animation to clear resources immediately
		animationView.stop()
		animationView.animation = nil
	}
	
	// Removed didMoveToSuperview() as VC will now handle play/stop
}

//class SPLottieCollectionViewCell: UICollectionViewCell {
//    
//    static let reuseIdentifier = "SPLottieCollectionViewCell"
//    
//    private let animationView: LottieAnimationView = {
//        let view = LottieAnimationView()
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.contentMode = .scaleAspectFit
//        view.loopMode = .loop
//        return view
//    }()
//    
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
//	func stop() {
//		
//	}
//	
//	func start() {
//		
//	}
//    
//    private func setupUI() {
//        // Add background color for testing
//        backgroundColor = .systemGray6
//        layer.cornerRadius = 8
//        layer.masksToBounds = true
//        
//        contentView.addSubview(animationView)
//        
//        NSLayoutConstraint.activate([
//            animationView.topAnchor.constraint(equalTo: contentView.topAnchor),
//            animationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//            animationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
//            animationView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
//        ])
//    }
//    
//    func configure(with url: URL?) {
//        // Cancel any previous loading
//        currentLoadTask?.cancel()
//        currentLoadTask = nil
//        animationView.stop()
//        animationView.animation = nil
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
//        // Load .tgs file (gzipped JSON)
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
//            // Create Lottie animation from decompressed JSON
//            DispatchQueue.main.async {
//                do {
//                    let animation = try LottieAnimation.from(data: jsonData)
//                    self.animationView.animation = animation
//                    self.animationView.play()
//                } catch {
//                    print("Error creating Lottie animation from TGS: \(error.localizedDescription)")
//                }
//            }
//        }
//        
//        currentLoadTask = task
//        task.resume()
//    }
//    
//    private func loadJSONFile(from url: URL) {
//        // Load JSON file - use Lottie's built-in URL loading
//        animationView.animation = nil
//        
//        if url.isFileURL {
//            // Local file
//            let filePath = url.path
//            animationView.animation = LottieAnimation.filepath(filePath)
//            animationView.play()
//        } else {
//            // Remote URL - load data and create animation
//            loadJSONFromURL(url)
//        }
//    }
//    
//    private func loadJSONFromURL(_ url: URL) {
//        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                print("Error loading JSON file: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let jsonData = data else {
//                print("No data received for JSON file")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                do {
//                    let animation = try LottieAnimation.from(data: jsonData)
//                    self.animationView.animation = animation
//                    self.animationView.play()
//                } catch {
//                    print("Error creating Lottie animation from JSON: \(error.localizedDescription)")
//                }
//            }
//        }
//        
//        currentLoadTask = task
//        task.resume()
//    }
//    
//    /// Decompresses gzipped data (for .tgs files)
//    private func decompressGzip(data: Data) -> Data? {
//        // .tgs files are gzipped JSON - use Compression framework
//        return data.gunzipped()
//    }
//    
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        currentLoadTask?.cancel()
//        currentLoadTask = nil
//        animationView.stop()
//        animationView.animation = nil
//    }
//    
//    // Pause animation when cell goes off-screen
//    override func didMoveToSuperview() {
//        super.didMoveToSuperview()
//        if superview == nil {
//            animationView.stop()
//        } else if animationView.animation != nil {
//            animationView.play()
//        }
//    }
//}
//
//// MARK: - Data Extension for Gzip Decompression
//
//import Compression
//import zlib
//
extension Data {
    /// Decompresses gzipped data (for .tgs files)
    /// Telegram .tgs files are gzipped JSON files
    func gunzipped() -> Data? {
        guard !isEmpty else { return nil }
        
        // Check for gzip magic number (1f 8b)
        guard count >= 2 else { return nil }
        let magic = withUnsafeBytes { $0.load(as: UInt16.self) }
        guard magic == 0x8b1f || magic == 0x1f8b else {
            // Not a gzip file, try direct decompression
            return nil
        }
        
        // Use zlib for gzip decompression (gzip uses deflate with header)
        // Create a mutable copy to work with
        var inputData = self
        
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
            stream.avail_in = UInt32(count)
            
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
}
