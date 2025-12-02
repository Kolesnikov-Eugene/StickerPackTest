//
//  SPCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 02.12.2025.
//

import UIKit
import SDWebImage

class SPWebpCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "SPWebpCollectionViewCell"
    
    private let imageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.autoPlayAnimatedImage = true // Automatically play animated images when loaded
        return imageView
    }()
    
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
        
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with url: URL?) {
        // Cancel any previous image loading
        imageView.sd_cancelCurrentImageLoad()
        
        // Reset animation state
        imageView.stopAnimating()
        imageView.image = nil
        
        // Load and animate WebP image
        // SDAnimatedImageView will automatically start animating when an animated image is loaded
        imageView.sd_setImage(with: url, placeholderImage: nil, options: [.progressiveLoad, .retryFailed]) { [weak self] image, error, cacheType, url in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                return
            }
            
            // Verify it's an animated image and start animation
            // SDAnimatedImageView should auto-animate, but we ensure it starts
            if let animatedImage = image as? SDAnimatedImage {
                if animatedImage.animatedImageFrameCount > 1 {
                    self?.imageView.startAnimating()
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
        imageView.stopAnimating()
    }
}
