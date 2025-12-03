//
//  SPCollectionViewController.swift
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 02.12.2025.
//

import UIKit
import SDWebImage

class SPCollectionViewController: UICollectionViewController {
    
    // MARK: - Configuration
    
    /// Sticker type mode: WebP or Lottie
    enum StickerMode {
        case webp
        case lottie
		case rlottie
    }
    
    /// Current sticker mode. Determines which cell type to use.
    var stickerMode: StickerMode = .webp
    
    /// Number of cells per row. Default is 4, easily configurable.
    var cellsPerRow: Int = 4 {
        didSet {
            updateLayout()
        }
    }
    
    // MARK: - Types
    
    private enum Section: Hashable {
        case main
    }
    
    /// Unique item identifier for diffable data source
    struct StickerItem: Hashable {
        let id: UUID
        let url: URL
        
        init(url: URL) {
            self.id = UUID()
            self.url = url
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: StickerItem, rhs: StickerItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Properties
    
    // All available URLs (full dataset - like from backend)
    private var allAvailableURLs: [URL] = []
    
    // Diffable data source
    private var dataSource: UICollectionViewDiffableDataSource<Section, StickerItem>!
    
    // Pagination configuration
    private let initialBatchSize: Int = 30 // First batch size
    private let loadMoreBatchSize: Int = 30 // Each subsequent batch
    private var isLoadingMore: Bool = false
    
    // MARK: - Initialization
    
    init() {
        let defaultCellsPerRow = 4
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            return Self.createLayoutSection(cellsPerRow: defaultCellsPerRow)
        }
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sticker pack styling
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        title = "" // No title for cleaner sticker pack look
        
        setupCollectionView()
        updateLayout() // Set the layout with the actual cellsPerRow value
        loadTestData()
    }
    
    // MARK: - Setup
    
    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        
        // Register both cell types
        collectionView.register(SPWebpCollectionViewCell.self, forCellWithReuseIdentifier: SPWebpCollectionViewCell.reuseIdentifier)
        collectionView.register(SPLottieCollectionViewCell.self, forCellWithReuseIdentifier: SPLottieCollectionViewCell.reuseIdentifier)
		collectionView.register(RLottieCollectionViewCell.self, forCellWithReuseIdentifier: RLottieCollectionViewCell.reuseIdentifier)
        
        collectionView.delegate = self
        
        // Ensure content respects safe area for bottom sheet
        collectionView.contentInsetAdjustmentBehavior = .always
        
        // Enable UICollectionView prefetching for better performance
        if #available(iOS 10.0, *) {
            collectionView.prefetchDataSource = self
            collectionView.isPrefetchingEnabled = true
        }
        
        // Setup diffable data source
        setupDataSource()
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, StickerItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self = self else {
                fatalError("Controller deallocated")
            }
            
            switch self.stickerMode {
            case .webp:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: SPWebpCollectionViewCell.reuseIdentifier,
                    for: indexPath
                ) as! SPWebpCollectionViewCell
                cell.configure(with: item.url)
                return cell
                
            case .lottie:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: SPLottieCollectionViewCell.reuseIdentifier,
                    for: indexPath
                ) as! SPLottieCollectionViewCell
                cell.configure(with: item.url)
                return cell
			case .rlottie:
				let cell = collectionView.dequeueReusableCell(
					withReuseIdentifier: RLottieCollectionViewCell.reuseIdentifier,
					for: indexPath
				) as! RLottieCollectionViewCell
				cell.configure(with: item.url)
				return cell
            }
        }
        
        collectionView.dataSource = dataSource
    }
    
    // MARK: - Layout Configuration
    
    private static func createLayoutSection(cellsPerRow: Int) -> NSCollectionLayoutSection {
        // Item size - each item takes 1/cellsPerRow of the width
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(cellsPerRow)),
            heightDimension: .fractionalWidth(1.0 / CGFloat(cellsPerRow))
        )
        
        // Create items for the group
        var items: [NSCollectionLayoutItem] = []
        for _ in 0..<cellsPerRow {
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            items.append(item)
        }
        
        // Group - contains cellsPerRow items in a horizontal row
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / CGFloat(cellsPerRow))
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: items)
        
        // Section with sticker pack style spacing
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 32, trailing: 12) // Extra bottom padding for sheet
        section.interGroupSpacing = 0 // No spacing between rows
        
        return section
    }
    
    private func createLayoutSection() -> NSCollectionLayoutSection {
        return Self.createLayoutSection(cellsPerRow: cellsPerRow)
    }
    
    private func updateLayout() {
        let newLayout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            return self?.createLayoutSection()
        }
        collectionView.setCollectionViewLayout(newLayout, animated: false)
    }
    
    // MARK: - Data Loading
    
    private func loadTestData() {
        var urls: [URL] = []
        
        switch stickerMode {
        case .webp:
            urls = loadWebPURLs()
        case .lottie:
            urls = loadLottieURLs()
		case .rlottie:
			urls = loadRlottieURLs()
        }
        
        // Store all URLs (like receiving from backend)
        allAvailableURLs = urls
        
        // Load initial batch (first 30 stickers)
        loadInitialBatch()
    }
    
    private func loadWebPURLs() -> [URL] {
        var urls: [URL] = []
        
        // Add remote animated WebP URLs
		let remoteURLs = [
			"https://isparta.github.io/compare-webp/image/gif_webp/webp/1.webp",
			"https://isparta.github.io/compare-webp/image/gif_webp/webp/2.webp",
			"https://shoelace.style/assets/images/walk.gif",
			"https://shoelace.style/assets/images/tie.webp",
			"https://convertico.com/samples/webp/animated-webp-3.webp",
			"https://sembiance.com/fileFormatSamples/image/webp/abydos.webp",
			"https://sembiance.com/fileFormatSamples/image/webp/animated.webp",
			"file:///Users/e.a.kolesnikov/webp_stickers/1.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/1.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/5.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/21.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/42.thumb128.webp",
			
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/2.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/45.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/31.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/3.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/4.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/5.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/6.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/7.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/8.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/9.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/10.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/11.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/12.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/13.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/14.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/15.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/16.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/17.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/18.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/19.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/20.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/22.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/23.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/24.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/25.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/26.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/27.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/28.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/29.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/30.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/31.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/32.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/33.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/34.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/35.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/36.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/37.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/38.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/39.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/40.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/41.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/42.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/43.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/44.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/45.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/46.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/47.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/48.thumb128.webp",
			"https://cdn.cdnstep.com/dTryYbfcB9lRWE2W3Y9z/49.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/0.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/1.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/2.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/3.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/4.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/5.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/6.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/7.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/8.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/9.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/10.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/11.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/12.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/13.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/14.thumb128.webp",
			"https://cdn.cdnstep.com/PjgjV2AVPuJyzYPQFtfd/15.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/0.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/1.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/2.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/3.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/4.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/5.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/6.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/7.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/8.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/9.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/10.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/11.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/12.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/13.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/14.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/15.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/16.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/17.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/18.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/19.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/20.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/21.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/22.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/23.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/24.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/25.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/26.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/27.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/28.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/29.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/30.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/31.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/32.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/33.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/34.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/35.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/36.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/37.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/38.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/39.thumb128.webp",
			"https://cdn.cdnstep.com/VWLBpKAUCUp11KZZ7lLg/40.thumb128.webp",
			
			
        ]
        
        urls.append(contentsOf: remoteURLs.compactMap { URL(string: $0) })
        
        return urls
    }
    
    private func loadLottieURLs() -> [URL] {
        var urls: [URL] = []
        
        // Load local .tgs files from bundle if available
        // To add local .tgs files: Create a folder "tgs_stickers" in your project,
        // add .tgs files to it, and ensure it's added as a "folder reference" (blue folder) in Xcode
        if let bundleURL = Bundle.main.resourceURL {
            let tgsDirectory = bundleURL.appendingPathComponent("tgs_stickers", isDirectory: true)
            if let tgsFiles = try? FileManager.default.contentsOfDirectory(
                at: tgsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                let tgsFiles = tgsFiles.filter { $0.pathExtension.lowercased() == "tgs" }
                urls.append(contentsOf: tgsFiles)
            }
        }
        
        // Add remote Lottie .tgs file URLs (Telegram sticker format)
        // Replace these with actual .tgs URLs from your backend/CDN
        let remoteTGSURLs: [String] = [
//			"file:///Users/e.a.kolesnikov/webp_stickers/123.tgs",
//			"file:///Users/e.a.kolesnikov/webp_stickers/test1.tgs",
//			"file:///Users/e.a.kolesnikov/webp_stickers/test2.tgs",
//			"file:///Users/e.a.kolesnikov/webp_stickers/test3.tgs",
//			"file:///Users/e.a.kolesnikov/webp_stickers/test4.tgs",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
        ]
        
        // Add remote URLs
        urls.append(contentsOf: remoteTGSURLs.compactMap { URL(string: $0) })
        
        // If no URLs found, log a warning
        if urls.isEmpty {
            print("Warning: No Lottie .tgs URLs found. Add .tgs files to 'tgs_stickers' folder in your bundle or provide remote URLs in loadLottieURLs().")
        }
        
        return urls
    }
	
	private func loadRlottieURLs() -> [URL] {
		var urls: [URL] = []
		
		let remoteRLottieUrls: [String] = [
			"file:///Users/e.a.kolesnikov/webp_stickers/angry.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/flashbacks.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/hi.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/like.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/money.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/smoke.json",
			"file:///Users/e.a.kolesnikov/webp_stickers/win.json",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/123.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/test1.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/test2.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/test3.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/test4.tgs",
			
			"file:///Users/e.a.kolesnikov/webp_stickers/a1.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a2.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a3.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a4.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a5.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a6.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a7.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a8.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a9.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a10.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a11.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a12.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a13.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a14.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a15.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a16.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a17.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/a18.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s1.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s2.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s3.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s4.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s5.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s6.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s7.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s8.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s9.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s10.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s11.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s12.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s13.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s14.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s15.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s16.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s17.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s18.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s19.tgs",
			"file:///Users/e.a.kolesnikov/webp_stickers/s20.tgs",
			
		]
		
		urls.append(contentsOf: remoteRLottieUrls.compactMap { URL(string: $0) })
		return urls
	}
    
    // MARK: - Dynamic Loading
    
    /// Get currently loaded items from snapshot
    private var loadedItems: [StickerItem] {
        guard let snapshot = dataSource?.snapshot() else { return [] }
        return snapshot.itemIdentifiers(inSection: .main)
    }
    
    /// Get currently loaded URLs count
    private var loadedImageURLsCount: Int {
        loadedItems.count
    }
    
    /// Load initial batch of stickers (like first response from backend)
    private func loadInitialBatch() {
        let batchSize = min(initialBatchSize, allAvailableURLs.count)
        let initialURLs = Array(allAvailableURLs.prefix(batchSize))
        
        // Create unique items for each URL
        let initialItems = initialURLs.map { StickerItem(url: $0) }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, StickerItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(initialItems, toSection: .main)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    /// Load more URLs when user scrolls (smart preloading)
    private func loadMoreContentIfNeeded() {
        // Prevent multiple simultaneous loads
        guard !isLoadingMore else { return }
        
        let currentCount = loadedImageURLsCount
        let remainingCount = allAvailableURLs.count - currentCount
        
        // If we've loaded everything, nothing to do
        guard remainingCount > 0 else { return }
        
        // Check if user is approaching the end (smart preloading)
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard let maxVisibleIndex = visibleIndexPaths.map({ $0.item }).max() else { return }
        
        // Preload when user is within 10 items of the end
        let preloadThreshold = currentCount - 10
        
        guard maxVisibleIndex >= preloadThreshold else { return }
        
        isLoadingMore = true
        
        let batchSize = min(loadMoreBatchSize, remainingCount)
        let nextBatchURLs = Array(allAvailableURLs[currentCount..<(currentCount + batchSize)])
        
        // Create unique items for each URL
        let nextBatchItems = nextBatchURLs.map { StickerItem(url: $0) }
        
        // Update snapshot with new items
        var snapshot = dataSource.snapshot()
        snapshot.appendItems(nextBatchItems, toSection: .main)
        
        // Apply snapshot with smooth animation
        dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
            self?.isLoadingMore = false
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        // Handle cell selection if needed
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Smart preloading: check if we need to load more content
        loadMoreContentIfNeeded()
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension SPCollectionViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Prefetch images for upcoming cells using SDWebImage
        let urlsToPrefetch = indexPaths.compactMap { indexPath -> URL? in
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return item.url
        }
        
        if !urlsToPrefetch.isEmpty {
            SDWebImagePrefetcher.shared.prefetchURLs(urlsToPrefetch)
        }
        
        // Also check if we need to load more URLs when prefetching near the end
        let currentCount = loadedImageURLsCount
        if let maxIndex = indexPaths.map({ $0.item }).max() {
            // If prefetching items near the end, trigger loading more URLs
            if maxIndex >= currentCount - 5 {
                loadMoreContentIfNeeded()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel prefetching for items that are no longer needed
        // SDWebImage handles cancellation internally
    }
}
