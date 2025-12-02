//
//  SPLottieCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 02.12.2025.
//

import UIKit
import Lottie

class SPLottieCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "SPLottieCollectionViewCell"
    
    private let animationView: LottieAnimationView = {
        let view = LottieAnimationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        return view
    }()
    
    private var currentLoadTask: URLSessionDataTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Add background color for testing
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
    
    func configure(with url: URL?) {
        // Cancel any previous loading
        currentLoadTask?.cancel()
        currentLoadTask = nil
        animationView.stop()
        animationView.animation = nil
        
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
        // Load .tgs file (gzipped JSON)
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
            
            // Create Lottie animation from decompressed JSON
            DispatchQueue.main.async {
                do {
                    let animation = try LottieAnimation.from(data: jsonData)
                    self.animationView.animation = animation
                    self.animationView.play()
                } catch {
                    print("Error creating Lottie animation from TGS: \(error.localizedDescription)")
                }
            }
        }
        
        currentLoadTask = task
        task.resume()
    }
    
    private func loadJSONFile(from url: URL) {
        // Load JSON file - use Lottie's built-in URL loading
        animationView.animation = nil
        
        if url.isFileURL {
            // Local file
            let filePath = url.path
            animationView.animation = LottieAnimation.filepath(filePath)
            animationView.play()
        } else {
            // Remote URL - load data and create animation
            loadJSONFromURL(url)
        }
    }
    
    private func loadJSONFromURL(_ url: URL) {
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
                do {
                    let animation = try LottieAnimation.from(data: jsonData)
                    self.animationView.animation = animation
                    self.animationView.play()
                } catch {
                    print("Error creating Lottie animation from JSON: \(error.localizedDescription)")
                }
            }
        }
        
        currentLoadTask = task
        task.resume()
    }
    
    /// Decompresses gzipped data (for .tgs files)
    private func decompressGzip(data: Data) -> Data? {
        // .tgs files are gzipped JSON - use Compression framework
        return data.gunzipped()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentLoadTask?.cancel()
        currentLoadTask = nil
        animationView.stop()
        animationView.animation = nil
    }
    
    // Pause animation when cell goes off-screen
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            animationView.stop()
        } else if animationView.animation != nil {
            animationView.play()
        }
    }
}

// MARK: - Data Extension for Gzip Decompression

import Compression
import zlib

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
