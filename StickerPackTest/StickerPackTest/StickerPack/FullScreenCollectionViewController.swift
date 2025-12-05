//
//  FullScreenCollectionViewController.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 05.12.2025.
//

import UIKit

class FullScreenCollectionViewController: UICollectionViewController {

	// MARK: - Configuration
	var visibleRows: Int = 4 {
		didSet { updateLayout() }
	}
	var cellMode: CellMode = .lottie
	enum CellMode {
		case rlottie
		case lottie
	}

	private enum Section { case main }

	struct StickerItem: Hashable {
		let id = UUID()
		let url: URL
	}

	// MARK: - Properties

	private var dataSource: UICollectionViewDiffableDataSource<Section, StickerItem>!
	private var isUpdatingLayout = false

	// MARK: - Init

	init() {
		let placeholderItem = NSCollectionLayoutItem(
			layoutSize: NSCollectionLayoutSize(
				widthDimension: .absolute(10),
				heightDimension: .absolute(10)
			)
		)

		let placeholderGroup = NSCollectionLayoutGroup.horizontal(
			layoutSize: NSCollectionLayoutSize(
				widthDimension: .fractionalWidth(1),
				heightDimension: .absolute(10)
			),
			subitems: [placeholderItem]
		)

		let placeholderSection = NSCollectionLayoutSection(group: placeholderGroup)

		let layout = UICollectionViewCompositionalLayout(section: placeholderSection)

		super.init(collectionViewLayout: layout)
	}

	required init?(coder: NSCoder) { fatalError() }

	// MARK: - Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = .systemBackground
		modalPresentationStyle = .fullScreen

		setupCollectionView()
		setupDataSource()
		loadStickerData()

		DispatchQueue.main.async { [weak self] in
			self?.updateLayout()
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		// Ensure we're scrolled to top after view appears
		scrollToTop()
	}

	// MARK: - Setup
	
	private func setupCollectionView() {
		collectionView.backgroundColor = .clear
		collectionView.isScrollEnabled = true
		collectionView.alwaysBounceVertical = true
		collectionView.contentInsetAdjustmentBehavior = .always

		collectionView.register(
			RLottieCollectionViewCell.self,
			forCellWithReuseIdentifier: RLottieCollectionViewCell.reuseIdentifier
		)
		
		collectionView.register(
			SPLottieCollectionViewCell.self,
			forCellWithReuseIdentifier: SPLottieCollectionViewCell.reuseIdentifier
		)
	}
	
//	override func viewDidLayoutSubviews() {
//		super.viewDidLayoutSubviews()
//		collectionView.setContentOffset(.zero, animated: false)
//	}

//	private func setupCollectionView() {
//		collectionView.backgroundColor = .clear
//		collectionView.isScrollEnabled = true
//		collectionView.alwaysBounceVertical = true
//		collectionView.contentInsetAdjustmentBehavior = .automatic
//
//		collectionView.register(
//			RLottieCollectionViewCell.self,
//			forCellWithReuseIdentifier: RLottieCollectionViewCell.reuseIdentifier
//		)
//	}

	private func setupDataSource() {
		dataSource = UICollectionViewDiffableDataSource<Section, StickerItem>(
			collectionView: collectionView
		) { collectionView, indexPath, item in
			switch self.cellMode {
			case .rlottie:
				let cell = collectionView.dequeueReusableCell(
					withReuseIdentifier: RLottieCollectionViewCell.reuseIdentifier,
					for: indexPath
				) as! RLottieCollectionViewCell

				cell.configure(with: item.url)
				return cell
			case .lottie:
				let cell = collectionView.dequeueReusableCell(
					withReuseIdentifier: SPLottieCollectionViewCell.reuseIdentifier,
					for: indexPath
				) as! SPLottieCollectionViewCell

				cell.configure(with: item.url)
				return cell
			}
			
		}
	}

	// MARK: - Layout
	
	private func createLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {

		let containerHeight = environment.container.contentSize.height
		let safeTop = view.safeAreaInsets.top
		let safeBottom = view.safeAreaInsets.bottom

		let availableHeight = containerHeight - safeTop - safeBottom
		let cellHeight = (availableHeight / CGFloat(visibleRows)) - 8
		let cellWidth = min(cellHeight, 200)

		// ITEM
		let itemSize = NSCollectionLayoutSize(
			widthDimension: .absolute(cellWidth),
			heightDimension: .absolute(cellHeight)
		)
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = .init(top: 4, leading: 0, bottom: 4, trailing: 0)

		// RIGHT ALIGNMENT
		let screenWidth = environment.container.effectiveContentSize.width
		let horizontalPadding: CGFloat = 16
		let availableWidth = screenWidth - horizontalPadding * 2
		let leftPadding = max(0, availableWidth - cellWidth)

		// ONE-ITEM GROUP
		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(cellHeight)
		)

		let group = NSCollectionLayoutGroup.horizontal(
			layoutSize: groupSize,
			subitems: [item]
		)

		// Push item to right side
		group.contentInsets = .init(
			top: 0,
			leading: leftPadding,
			bottom: 0,
			trailing: 0
		)

		// SECTION
		let section = NSCollectionLayoutSection(group: group)
		section.interGroupSpacing = 8
		section.contentInsets = .init(
			top: 0,
			leading: horizontalPadding,
			bottom: 0,
			trailing: horizontalPadding
		)

		return section
	}

//	private func createLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
//
//		let containerHeight = environment.container.contentSize.height
//		let safeTop = view.safeAreaInsets.top
//		let safeBottom = view.safeAreaInsets.bottom
//
//		let availableHeight = containerHeight - safeTop - safeBottom
//		let cellHeight = (availableHeight / CGFloat(visibleRows)) - 8
//		let cellWidth = min(cellHeight, 200)
//
//		let itemSize = NSCollectionLayoutSize(
//			widthDimension: .absolute(cellWidth),
//			heightDimension: .absolute(cellHeight)
//		)
//		let item = NSCollectionLayoutItem(layoutSize: itemSize)
//		item.contentInsets = .init(top: 4, leading: 4, bottom: 4, trailing: 4)
//
//		let screenWidth = environment.container.effectiveContentSize.width
//		let horizontalPadding: CGFloat = 16
//		let availableWidth = screenWidth - horizontalPadding * 2
//		let spacerWidth = max(0, availableWidth - cellWidth)
//
//		let spacerSize = NSCollectionLayoutSize(
//			widthDimension: .absolute(spacerWidth),
//			heightDimension: .fractionalHeight(1.0)
//		)
//		let spacer = NSCollectionLayoutItem(layoutSize: spacerSize)
//
//		let groupSize = NSCollectionLayoutSize(
//			widthDimension: .fractionalWidth(1.0),
//			heightDimension: .absolute(cellHeight)
//		)
//
//		let group = NSCollectionLayoutGroup.horizontal(
//			layoutSize: groupSize,
//			subitems: [spacer, item]
//		)
//
//		let section = NSCollectionLayoutSection(group: group)
//		section.interGroupSpacing = 8
//		section.contentInsets = .init(
//			top: 0,
//			leading: horizontalPadding,
//			bottom: 0,
//			trailing: horizontalPadding
//		)
//
//		return section
//	}

	private func updateLayout() {
		guard !isUpdatingLayout else { return }
		isUpdatingLayout = true

		let newLayout = UICollectionViewCompositionalLayout { [weak self] _, env in
			guard let self = self else { return nil }
			return self.createLayoutSection(environment: env)
		}

		collectionView.setCollectionViewLayout(newLayout, animated: false)

		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			self.isUpdatingLayout = false
			// Reset scroll position to top after layout update
			self.scrollToTop()
		}
	}
	
	private func scrollToTop() {
		guard collectionView.numberOfSections > 0,
			  collectionView.numberOfItems(inSection: 0) > 0 else { return }
		
		let topIndexPath = IndexPath(item: 0, section: 0)
		collectionView.scrollToItem(at: topIndexPath, at: .top, animated: false)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: nil) { _ in
			self.updateLayout()
		}
	}

	// MARK: - Data

	private func loadStickerData() {
		let urls = loadLocalLottieURLs()
		let items = urls.map { StickerItem(url: $0) }

		var snapshot = NSDiffableDataSourceSnapshot<Section, StickerItem>()
		snapshot.appendSections([.main])
		snapshot.appendItems(items)

		dataSource.apply(snapshot, animatingDifferences: false)
	}

	private func loadLocalLottieURLs() -> [URL] {
		var urls: [URL] = []

		if let bundlePath = Bundle.main.resourcePath {
			let fm = FileManager.default
			let stickersPath = (bundlePath as NSString).appendingPathComponent("stickers")

			var isDir: ObjCBool = false
			if fm.fileExists(atPath: stickersPath, isDirectory: &isDir), isDir.boolValue {
				urls += findStickerFiles(in: URL(fileURLWithPath: stickersPath)) ?? []
			} else {
				if let bundleURL = Bundle.main.resourceURL,
				   let allFiles = try? fm.contentsOfDirectory(
					at: bundleURL,
					includingPropertiesForKeys: nil,
					options: [.skipsHiddenFiles]
				) {
					urls += allFiles.filter { ["json", "tgs"].contains($0.pathExtension) }
				}
			}
		}

		return Array(Set(urls)).sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	private func findStickerFiles(in directory: URL) -> [URL]? {
		let fm = FileManager.default
		guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }

		return enumerator.compactMap { element in
			guard let url = element as? URL else { return nil }
			let ext = url.pathExtension.lowercased()
			return (ext == "json" || ext == "tgs") ? url : nil
		}
	}

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		collectionView.deselectItem(at: indexPath, animated: true)
	}
}
