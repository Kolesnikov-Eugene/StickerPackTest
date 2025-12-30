import UIKit
import AsyncDisplayKit

// Import the extracted modules
// If all files are in the same target, these imports may not be needed
// If you've set up separate modules, uncomment and adjust module names as needed:
// import AnimatedStickerNode  // For DefaultAnimatedStickerNodeImpl
// import TelegramAnimatedStickerNode  // For FileAnimatedStickerSource, DataAnimatedStickerSource
// import MediaResources  // For EmojiFitzModifier, AnimatedStickerMode, AnimatedStickerPlaybackMode

/// A UICollectionViewCell that displays animated Lottie stickers using DefaultAnimatedStickerNodeImpl
/// 
/// This implementation uses DefaultAnimatedStickerNodeImpl which provides:
/// - Optional Metal-accelerated rendering
/// - Frame caching support
/// - More advanced features for complex animations
/// 
/// See ANIMATED_STICKER_NODE_OPTIONS.md for comparison with DirectAnimatedStickerNode
public final class AnimatedStickerCollectionViewCellWithDefaultNode: UICollectionViewCell {
    
    // MARK: - Properties
    
    /// The animated sticker node that handles rendering using DefaultAnimatedStickerNodeImpl
    private let animationNode: DefaultAnimatedStickerNodeImpl
    
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
    
    /// Whether to use Metal-accelerated rendering (default: false)
    /// Set this before calling configure() to enable Metal acceleration
    public var useMetalCache: Bool = false {
        didSet {
            // Note: This can only be set before the node is created
            // If you need to change it, recreate the cell
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize with optional Metal cache support
    /// - Parameter useMetalCache: Whether to use Metal-accelerated rendering (default: false)
    public init(useMetalCache: Bool = false) {
        // Create the animation node with optional Metal support
        self.animationNode = DefaultAnimatedStickerNodeImpl(useMetalCache: useMetalCache)
        self.useMetalCache = useMetalCache
        
        // Configure the node
        // DefaultAnimatedStickerNodeImpl uses visibility + isDisplaying to control playback
        // The eventsNode automatically tracks when the node enters/exits the view hierarchy
        self.animationNode.automaticallyLoadFirstFrame = true
        self.animationNode.autoplay = false  // We control via visibility (which triggers updateIsPlaying)
        
        super.init(frame: .zero)
        
        setupNode()
    }
    
    public override init(frame: CGRect) {
        // Default initialization without Metal
        self.animationNode = DefaultAnimatedStickerNodeImpl(useMetalCache: false)
        self.useMetalCache = false
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
    ///   - cachePathPrefix: Optional cache path prefix for frame caching (nil = no caching)
    ///   - useCachedMode: Whether to use cached mode instead of direct mode (default: false)
    public func configure(
        with filePath: String,
        size: CGSize = CGSize(width: 200, height: 200),
        cachePathPrefix: String? = nil,
        useCachedMode: Bool = false
    ) {
        // Reset if file path changed
        if self.stickerFilePath != filePath {
            self.stickerFilePath = filePath
            self.animationSize = size
            
            // Reset the animation node
            self.animationNode.reset()
            
            // Create source from file path
            let source = FileAnimatedStickerSource(filePath: filePath, isVideo: false)
            
            // Setup the animation node
            // Choose between .direct (faster, no caching) or .cached (with frame caching)
            let mode: AnimatedStickerMode = useCachedMode ? .cached : .direct(cachePathPrefix: cachePathPrefix)
            self.animationNode.setup(
                source: source,
				width: Int(size.width * 1.3),
				height: Int(size.height * 1.3),
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
    ///   - cachePathPrefix: Optional cache path prefix for frame caching (nil = no caching)
    ///   - useCachedMode: Whether to use cached mode instead of direct mode (default: false)
    public func configure(
        with data: Data,
        size: CGSize = CGSize(width: 200, height: 200),
        cachePathPrefix: String? = nil,
        useCachedMode: Bool = false
    ) {
        self.animationSize = size
        
        // Reset the animation node
        self.animationNode.reset()
        
        // Create source from data
        let source = DataAnimatedStickerSource(data: data, isVideo: false)
        
        // Setup the animation node
        let mode: AnimatedStickerMode = useCachedMode ? .cached : .direct(cachePathPrefix: cachePathPrefix)
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
        // DefaultAnimatedStickerNodeImpl automatically handles playback when visibility changes
        // The visibility setter triggers updateIsPlaying() which handles play/pause automatically
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
    
    // MARK: - Advanced Features (DefaultAnimatedStickerNodeImpl specific)
    
    /// Set a dynamic color for template rendering
    /// This allows you to tint the animation
    /// - Parameter color: The color to use for tinting (nil = no tinting)
    public func setDynamicColor(_ color: UIColor?) {
        self.animationNode.dynamicColor = color
    }
    
    /// Get the current frame image
    /// - Returns: The current frame as a UIImage, or nil if not available
    public func getCurrentFrameImage() -> UIImage? {
        return self.animationNode.currentFrameImage
    }
}

