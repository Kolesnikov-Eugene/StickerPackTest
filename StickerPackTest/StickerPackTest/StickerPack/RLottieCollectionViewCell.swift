//
//  RLottieCollectionViewCell.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//

import UIKit

class RLottieCollectionViewCell: UICollectionViewCell {
    
	static let reuseIdentifier = "RLottieCollectionViewCell"
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupUI()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func configure(with url: URL?) {}
	
	private func setupUI() {
		
	}
}
