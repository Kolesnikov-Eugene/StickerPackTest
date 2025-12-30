import Foundation
// Simplified AnimatedStickerResourceSource that works with file paths
// This doesn't require Postbox/TelegramCore dependencies

public final class FileAnimatedStickerSource: AnimatedStickerNodeSource {
    public var fitzModifier: EmojiFitzModifier?
    public let isVideo: Bool
    public let filePath: String
    
    public init(filePath: String, fitzModifier: EmojiFitzModifier? = nil, isVideo: Bool = false) {
        self.filePath = filePath
        self.fitzModifier = fitzModifier
        self.isVideo = isVideo
    }
    
    public func directDataPath(attemptSynchronously: Bool) -> Signal<String?, NoError> {
        if FileManager.default.fileExists(atPath: filePath) {
            return .single(filePath)
        } else {
            return .single(nil)
        }
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return .never()
    }
}

// Simplified version that works with Data
public final class DataAnimatedStickerSource: AnimatedStickerNodeSource {
    public var fitzModifier: EmojiFitzModifier?
    public let isVideo: Bool
    private let data: Data
    
    public init(data: Data, fitzModifier: EmojiFitzModifier? = nil, isVideo: Bool = false) {
        self.data = data
        self.fitzModifier = fitzModifier
        self.isVideo = isVideo
    }
    
    public func directDataPath(attemptSynchronously: Bool) -> Signal<String?, NoError> {
        return Signal { subscriber in
            // Write data to temp file
			let tempFile = NSTemporaryDirectory() + UUID().uuidString + (self.isVideo ? ".webm" : ".tgs")
            do {
				try self.data.write(to: URL(fileURLWithPath: tempFile))
                subscriber.putNext(tempFile)
            } catch {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return .never()
    }
}

