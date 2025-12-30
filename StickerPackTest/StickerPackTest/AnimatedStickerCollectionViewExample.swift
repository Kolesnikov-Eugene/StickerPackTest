import UIKit
import AsyncDisplayKit

/// Example usage of AnimatedStickerCollectionViewCell in a UICollectionViewController
public class AnimatedStickerCollectionViewController: UICollectionViewController {
    
    // MARK: - Properties
    
    /// Array of file paths to Lottie JSON files
    private let stickerFilePaths: [String]
    
    /// Cell size configuration
    private let cellSize: CGSize
    
    // MARK: - Initialization
    
    public init(stickerFilePaths: [String], cellSize: CGSize = CGSize(width: 70, height: 70)) {
        self.stickerFilePaths = stickerFilePaths
        self.cellSize = cellSize
        
        // Configure layout
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = cellSize
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register cell
//        self.collectionView.register(
//            AnimatedStickerCollectionViewCell.self,
//            forCellWithReuseIdentifier: "AnimatedStickerCell"
//        )
		self.collectionView.register(
			AnimatedStickerCollectionViewCellWithDefaultNode.self,
			forCellWithReuseIdentifier: "AnimatedStickerCell"
		)
        
        // Configure collection view
		self.collectionView.backgroundColor = .systemBackground
    }
    
    // MARK: - UICollectionViewDataSource
    
    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.stickerFilePaths.count
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "AnimatedStickerCell",
            for: indexPath
//        ) as! AnimatedStickerCollectionViewCell
			) as! AnimatedStickerCollectionViewCellWithDefaultNode
        
        // Configure cell with file path
        let filePath = self.stickerFilePaths[indexPath.item]
        cell.configure(with: filePath, size: self.cellSize)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    public override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Start animation when cell becomes visible
        if let animatedCell = cell as? AnimatedStickerCollectionViewCellWithDefaultNode {
            animatedCell.willDisplay()
        }
    }
    
    public override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Stop animation when cell is no longer visible
//        if let animatedCell = cell as? AnimatedStickerCollectionViewCell {
//            animatedCell.didEndDisplaying()
//        }
		if let animatedCell = cell as? AnimatedStickerCollectionViewCellWithDefaultNode {
			animatedCell.didEndDisplaying()
		}
    }
}

// MARK: - Usage Example

/*
// Example: How to use in your app
 
// 1. Create an array of Lottie JSON file paths
let stickerPaths = [
    Bundle.main.path(forResource: "sticker1", ofType: "json") ?? "",
    Bundle.main.path(forResource: "sticker2", ofType: "tgs") ?? "",
    // Add more paths...
]

// 2. Create and present the collection view controller
let viewController = AnimatedStickerCollectionViewController(
    stickerFilePaths: stickerPaths,
    cellSize: CGSize(width: 200, height: 200)
)

// 3. Present or push the view controller
navigationController?.pushViewController(viewController, animated: true)
// or
present(viewController, animated: true)

// Alternative: Use the cell directly in your own collection view
 
// In your UICollectionViewDataSource:
func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "AnimatedStickerCell",
        for: indexPath
    ) as! AnimatedStickerCollectionViewCell
    
    let filePath = self.stickerFilePaths[indexPath.item]
    cell.configure(with: filePath, size: CGSize(width: 200, height: 200))
    
    return cell
}

// In your UICollectionViewDelegate:
func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if let animatedCell = cell as? AnimatedStickerCollectionViewCell {
        animatedCell.willDisplay()
    }
}

func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if let animatedCell = cell as? AnimatedStickerCollectionViewCell {
        animatedCell.didEndDisplaying()
    }
}
*/

