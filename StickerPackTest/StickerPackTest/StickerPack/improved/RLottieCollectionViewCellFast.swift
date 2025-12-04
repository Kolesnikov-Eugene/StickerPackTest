//
//  RLottieCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 04.12.2025.
//

import UIKit
import Compression
import zlib

class RLottieCollectionViewCellFast: UICollectionViewCell {
	static let reuseIdentifier = "RLottieCollectionViewCellFast"

	private let imageView: UIImageView = {
		let view = UIImageView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.contentMode = .scaleAspectFit
		view.clipsToBounds = true
		return view
	}()

	private var player: RLottiePlayer?
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
		stopPlayback()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		imageView.image = nil
		player = nil

		guard let url = url else { return }
		let ext = url.pathExtension.lowercased()
		if ext == "tgs" {
			loadTGSFile(from: url)
		} else if ext == "json" || ext.isEmpty {
			loadJSONFile(from: url)
		} else {
			print("Unsupported: \(ext)")
		}
	}

	private func loadTGSFile(from url: URL) {
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
			guard let self = self else { return }
			if let error = error { print("tgs load error: \(error)"); return }
			guard let compressed = data else { return }
			guard let jsonData = self.decompressGzip(data: compressed) else {
				print("Failed to decompress")
				return
			}
			DispatchQueue.main.async { self.createPlayer(from: jsonData) }
		}
		currentLoadTask = task
		task.resume()
	}

	private func loadJSONFile(from url: URL) {
		if url.isFileURL {
			guard let d = try? Data(contentsOf: url) else { return }
			createPlayer(from: d)
		} else {
			let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
				guard let self = self else { return }
				if let err = err { print("json load err: \(err)") ; return }
				guard let d = data else { return }
				DispatchQueue.main.async { self.createPlayer(from: d) }
			}
			currentLoadTask = task
			task.resume()
		}
	}

	private func createPlayer(from data: Data) {
		guard let anim = RLottieAnimationFast(data: data) else {
			print("Failed to init rlottie")
			return
		}
		// Use smaller maxDimension (320) by default
		let p = RLottiePlayer(animation: anim, imageView: imageView, maxDimension: 320, preferredFPS: 120)
		self.player = p
		p!.start()
	}

	private func stopPlayback() {
		player?.stop()
		player = nil
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		stopPlayback()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		imageView.image = nil
	}

	// decompressGzip remains same as your implementation
	private func decompressGzip(data: Data) -> Data? { /* copy your previous impl */
		guard !data.isEmpty else { return nil }
		guard data.count >= 2 else { return nil }
		let magic = data.withUnsafeBytes { $0.load(as: UInt16.self) }
		guard magic == 0x8b1f || magic == 0x1f8b else { return nil }

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
				guard result == Z_OK || result == Z_STREAM_END else { return nil }
				let written = bufferSize - Int(stream.avail_out)
				if written > 0 { decompressed.append(contentsOf: buffer.prefix(written)) }
			} while stream.avail_out == 0 && result != Z_STREAM_END

			return result == Z_STREAM_END ? decompressed : nil
		}
	}
}
