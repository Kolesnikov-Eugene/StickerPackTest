//
//  ViewController.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 02.12.2025.
//

import UIKit
import SDWebImage
import SDWebImageWebPCoder

class ViewController: UIViewController {
	
	private lazy var webpButton: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	private lazy var lottieButton: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	private lazy var rlottieButton: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	private lazy var rlottieMetalButton: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	private lazy var rlottieButtonv2: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	private lazy var rlottieFastButton: UIButton = {
		let button = UIButton(type: .system)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		
		// init sdwebimage
		let coder = SDImageWebPCoder.shared
		SDImageCodersManager.shared.addCoder(coder)
		
		let prefetcher = SDWebImagePrefetcher.shared
		prefetcher.maxConcurrentPrefetchCount = 1   // VERY important
		prefetcher.options = [.scaleDownLargeImages] 
		
		setupUI()
		
		webpButton.setTitle("Present WebP Controller", for: .normal)
		lottieButton.setTitle("Present Lottie Controller", for: .normal)
		rlottieButton.setTitle("Present Rlottie Controller", for: .normal)
		rlottieMetalButton.setTitle("Present rlottieMetal", for: .normal)
		rlottieButtonv2.setTitle("Present rlottie v2", for: .normal)
		rlottieFastButton.setTitle("Present rlottie fast", for: .normal)
		
		webpButton.addTarget(self, action: #selector(presentWebpController), for: .touchUpInside)
		lottieButton.addTarget(self, action: #selector(presentLottieController), for: .touchUpInside)
		rlottieButton.addTarget(self, action: #selector(presentRlottieController), for: .touchUpInside)
		rlottieMetalButton.addTarget(self, action: #selector(presentRlottieMetal), for: .touchUpInside)
		rlottieButtonv2.addTarget(self, action: #selector(presentRlottiev2), for: .touchUpInside)
		rlottieFastButton.addTarget(self, action: #selector(presentrlottiefast), for: .touchUpInside)
	}
	
	private func setupUI() {
		view.addSubview(webpButton)
		view.addSubview(lottieButton)
		view.addSubview(rlottieButton)
		view.addSubview(rlottieMetalButton)
		view.addSubview(rlottieButtonv2)
		view.addSubview(rlottieFastButton)
		
		NSLayoutConstraint.activate([
			webpButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			webpButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
			
			lottieButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			lottieButton.topAnchor.constraint(equalTo: webpButton.bottomAnchor, constant: 20),
			
			rlottieButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			rlottieButton.topAnchor.constraint(equalTo: lottieButton.bottomAnchor, constant: 20),
			
			rlottieMetalButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			rlottieMetalButton.topAnchor.constraint(equalTo: rlottieButton.bottomAnchor, constant: 20),
			
			rlottieButtonv2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			rlottieButtonv2.topAnchor.constraint(equalTo: rlottieMetalButton.bottomAnchor, constant: 20),
			
			rlottieFastButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			rlottieFastButton.topAnchor.constraint(equalTo: rlottieButtonv2.bottomAnchor, constant: 20),
		])
	}
	
	@objc
	private func presentWebpController() {
		let webpController = SPCollectionViewController()
		webpController.cellsPerRow = 5
		
		// Wrap in navigation controller for proper presentation
//		let navController = UINavigationController(rootViewController: webpController)
		
		// Configure for bottom sheet presentation (sticker pack style)
		if #available(iOS 15.0, *) {
			if let sheet = webpController.sheetPresentationController {
				
				// Create custom detent for keyboard-like height
				// Typical keyboard height: iPhone = ~216-300 points, iPad = ~400 points
				// Adjust this value to match your desired height (250-350 is typical)
				let keyboardHeight: CGFloat = 300
				
				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
					// Return fixed height - this will be approximately keyboard height
					keyboardHeight
				}
				
				// Configure sheet - starts at keyboard height, allows expanding to medium/large
				// If you only want keyboard height (no resizing), use: [keyboardHeightDetent]
				sheet.detents = [keyboardHeightDetent]
				sheet.preferredCornerRadius = 16 // Rounded top corners
				sheet.prefersGrabberVisible = true // Show drag handle at top
				
				// Sheet will automatically start at the smallest detent (keyboard height)
			}
		}
		
		// Present as modal bottom sheet
		present(webpController, animated: true)
	}
	
	@objc
	private func presentLottieController() {
		let lottieController = SPCollectionViewController()
		lottieController.stickerMode = .lottie
		lottieController.cellsPerRow = 5
		
		// Configure for bottom sheet presentation (sticker pack style)
		if #available(iOS 15.0, *) {
			if let sheet = lottieController.sheetPresentationController {
				
				// Create custom detent for keyboard-like height
				let keyboardHeight: CGFloat = 300
				
				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
					keyboardHeight
				}
				
				// Configure sheet
				sheet.detents = [keyboardHeightDetent]
				sheet.preferredCornerRadius = 16
				sheet.prefersGrabberVisible = true
			}
		}
		
		// Present as modal bottom sheet
		present(lottieController, animated: true)
	}
	
	@objc
	private func presentRlottieController() {
		let rlottieController = SPCollectionViewController()
		rlottieController.stickerMode = .rlottie
		rlottieController.cellsPerRow = 5
		
		// Configure for bottom sheet presentation (sticker pack style)
		if #available(iOS 15.0, *) {
			if let sheet = rlottieController.sheetPresentationController {
				
				// Create custom detent for keyboard-like height
				let keyboardHeight: CGFloat = 300
				
				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
					keyboardHeight
				}
				
				// Configure sheet
				sheet.detents = [keyboardHeightDetent]
				sheet.preferredCornerRadius = 16
				sheet.prefersGrabberVisible = true
			}
		}
		
		// Present as modal bottom sheet
		present(rlottieController, animated: true)
	}
	
	@objc
	private func presentRlottieMetal() {
		let rlottieController = SPCollectionViewController()
		rlottieController.stickerMode = .rlottieMetal
		rlottieController.cellsPerRow = 5
		
		// Configure for bottom sheet presentation (sticker pack style)
		if #available(iOS 15.0, *) {
			if let sheet = rlottieController.sheetPresentationController {
				
				// Create custom detent for keyboard-like height
				let keyboardHeight: CGFloat = 300
				
				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
					keyboardHeight
				}
				
				// Configure sheet
				sheet.detents = [keyboardHeightDetent]
				sheet.preferredCornerRadius = 16
				sheet.prefersGrabberVisible = true
			}
		}
		
		// Present as modal bottom sheet
		present(rlottieController, animated: true)
	}
	
	@objc
	private func presentRlottiev2() {
		let rlottieController = SPCollectionViewController()
		rlottieController.stickerMode = .rlottiev2
		rlottieController.cellsPerRow = 5
		
		// Configure for bottom sheet presentation (sticker pack style)
		if #available(iOS 15.0, *) {
			if let sheet = rlottieController.sheetPresentationController {
				
				// Create custom detent for keyboard-like height
				let keyboardHeight: CGFloat = 300
				
				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
					keyboardHeight
				}
				
				// Configure sheet
				sheet.detents = [keyboardHeightDetent]
				sheet.preferredCornerRadius = 16
				sheet.prefersGrabberVisible = true
			}
		}
		
		// Present as modal bottom sheet
		present(rlottieController, animated: true)
	}
	
	@objc
	private func presentrlottiefast() {
//		let rlottieController = SPCollectionViewController()
//		rlottieController.stickerMode = .rlottieFast
//		rlottieController.cellsPerRow = 5
		let rlottieController = FullScreenCollectionViewController()
//		let rlottieController = SPCollectionViewController()
//		rlottieController.stickerMode = .rlottie
//		rlottieController.cellsPerRow = 2
		
		// Configure for bottom sheet presentation (sticker pack style)
//		if #available(iOS 15.0, *) {
//			if let sheet = rlottieController.sheetPresentationController {
//				
//				// Create custom detent for keyboard-like height
//				let keyboardHeight: CGFloat = 300
//				
//				let keyboardHeightDetent = UISheetPresentationController.Detent.custom { context in
//					keyboardHeight
//				}
//				
//				// Configure sheet
//				sheet.detents = [keyboardHeightDetent]
//				sheet.preferredCornerRadius = 16
//				sheet.prefersGrabberVisible = true
//			}
//		}
		
		// Present as modal bottom sheet
//		present(rlottieController, animated: true)
		navigationController?.pushViewController(rlottieController, animated: true)
	}
}
