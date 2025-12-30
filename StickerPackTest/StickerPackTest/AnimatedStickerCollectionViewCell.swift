import UIKit
import AsyncDisplayKit

// Import the extracted modules
// If all files are in the same target, these imports may not be needed
// If you've set up separate modules, uncomment and adjust module names as needed:
// import AnimatedStickerNode  // For DirectAnimatedStickerNode
// import TelegramAnimatedStickerNode  // For FileAnimatedStickerSource, DataAnimatedStickerSource
// import MediaResources  // For EmojiFitzModifier, AnimatedStickerMode, AnimatedStickerPlaybackMode

/// A UICollectionViewCell that displays animated Lottie stickers using rlottie
public final class AnimatedStickerCollectionViewCell: UICollectionViewCell {
    
    // MARK: - Properties
    
    /// The animated sticker node that handles rendering
    private let animationNode: DirectAnimatedStickerNode
    
    /// The file path to the Lottie JSON file
    private var stickerFilePath: String?
    
    /// The size at which to render the animation
    private var animationSize: CGSize = CGSize(width: 200, height: 200)
    
    /// Whether the cell is currently visible (used to control playback)
    private var isVisible: Bool = false {
        didSet {
            updateVisibility()
        }
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        // Create the animation node
        self.animationNode = DirectAnimatedStickerNode()
        self.animationNode.automaticallyLoadFirstFrame = true
        self.animationNode.autoplay = true
        
        super.init(frame: frame)
        
        setupNode()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupNode() {
        // Add the node as a subview
        self.contentView.addSubnode(self.animationNode)
        
        // Configure the node
        self.animationNode.view.contentMode = .scaleAspectFit
    }
    
    // MARK: - Configuration
    
    /// Configure the cell with a Lottie JSON file path
    /// - Parameters:
    ///   - filePath: Path to the Lottie JSON file (.json or .tgs)
    ///   - size: The size at which to render the animation (default: 200x200)
    public func configure(with filePath: String, size: CGSize = CGSize(width: 200, height: 200)) {
        // Reset if file path changed
		print("file path is \(filePath)")
        if self.stickerFilePath != filePath {
            self.stickerFilePath = filePath
            self.animationSize = size
            
            // Reset the animation node
            self.animationNode.reset()
            
            // Create source from file path
            let source = FileAnimatedStickerSource(filePath: filePath, isVideo: false)
            
            // Setup the animation node
            let mode: AnimatedStickerMode = .direct(cachePathPrefix: nil)
            self.animationNode.setup(
                source: source,
				width: Int(size.width),
				height: Int(size.height),
                playbackMode: .loop,
                mode: mode
            )
            
            // Update layout
            updateLayout()
        }
    }
    
    /// Configure the cell with Lottie JSON data
    /// - Parameters:
    ///   - data: The Lottie JSON data
    ///   - size: The size at which to render the animation (default: 200x200)
    public func configure(with data: Data, size: CGSize = CGSize(width: 200, height: 200)) {
        self.animationSize = size
        
        // Reset the animation node
        self.animationNode.reset()
        
        // Create source from data
        let source = DataAnimatedStickerSource(data: data, isVideo: false)
        
        // Setup the animation node
        let mode: AnimatedStickerMode = .direct(cachePathPrefix: nil)
        self.animationNode.setup(
            source: source,
			width: Int(size.width * 1.5),
			height: Int(size.height * 1.5),
            playbackMode: .loop,
            mode: mode
        )
        
        // Update layout
        updateLayout()
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    private func updateLayout() {
        // Center the animation node in the cell
        let nodeSize = self.animationSize
        let nodeFrame = CGRect(
            x: (self.contentView.bounds.width - nodeSize.width) / 2,
            y: (self.contentView.bounds.height - nodeSize.height) / 2,
            width: nodeSize.width,
            height: nodeSize.height
        )
        
        self.animationNode.frame = nodeFrame
        self.animationNode.updateLayout(size: nodeSize)
    }
    
    // MARK: - Visibility Management
    
    /// Call this when the cell becomes visible (e.g., in willDisplay)
    public func willDisplay() {
        self.isVisible = true
    }
    
    /// Call this when the cell is no longer visible (e.g., in didEndDisplaying)
    public func didEndDisplaying() {
        self.isVisible = false
    }
    
    private func updateVisibility() {
        // Control playback based on visibility
        self.animationNode.visibility = self.isVisible
    }
    
    // MARK: - Cell Reuse
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        // Stop animation and reset
        self.animationNode.stop()
        self.animationNode.reset()
        self.isVisible = false
        self.stickerFilePath = nil
    }
    
    // MARK: - Playback Control
    
    /// Play the animation once
    public func playOnce() {
        self.animationNode.playOnce()
    }
    
    /// Play the animation in a loop
    public func playLoop() {
        self.animationNode.playLoop()
    }
    
    /// Pause the animation
    public func pause() {
        self.animationNode.pause()
    }
    
    /// Stop the animation
    public func stop() {
        self.animationNode.stop()
    }
}

