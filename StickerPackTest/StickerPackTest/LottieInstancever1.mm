//
//  LottieInstance.mm
//  StickerPackTest
//
//  Created based on Telegram's implementation
//

#include "LottieInstancever1.h"
#include <rlottie.h>
#include <stdint.h>
#include <memory>
#include <string>
#include <atomic>
#include <map>
#include <cstring>

using namespace rlottie;

// Fitz modifier types (Telegram's Fitzpatrick scale)
enum FitzModifierType {
    FitzNone = 0,
    FitzType1 = 1,  // Light skin
    FitzType2 = 2,
    FitzType3 = 3,
    FitzType4 = 4,
    FitzType5 = 5   // Dark skin
};

// Color replacement map for Fitz modifiers
struct ColorReplacement {
    uint32_t fromColor;
    uint32_t toColor;
};

// Fitz modifier color replacements (simplified - Telegram has more sophisticated mapping)
static const std::map<int, std::vector<ColorReplacement>> fitzColorReplacements = {
    {FitzType1, {
        // Light skin tone replacements
        {0xFFDBAC99, 0xFFF4D1C0}, // Example colors - adjust based on your needs
    }},
    {FitzType2, {
        {0xFFDBAC99, 0xFFE8C5A0},
    }},
    {FitzType3, {
        {0xFFDBAC99, 0xFFD4A574},
    }},
    {FitzType4, {
        {0xFFDBAC99, 0xFFB07D4E},
    }},
    {FitzType5, {
        {0xFFDBAC99, 0xFF8B5A3C},
    }},
};

// Forward declaration
static void convertBGRAToARGBPremultiplied(uint8_t* buffer, int width, int height, int bytesPerRow);

// Apply Fitz modifier color replacements
static void applyFitzModifier(uint8_t* bufferRGBA, int width, int height, int bytesPerRow, int fitzModifier) {
    if (fitzModifier == FitzNone || fitzModifier < FitzType1 || fitzModifier > FitzType5) {
        return;
    }
    
    auto replacements = fitzColorReplacements.find(fitzModifier);
    if (replacements == fitzColorReplacements.end()) {
        return;
    }
    
    for (int y = 0; y < height; y++) {
        uint32_t* row = reinterpret_cast<uint32_t*>(bufferRGBA + y * bytesPerRow);
        for (int x = 0; x < width; x++) {
            uint32_t pixel = row[x];
            
            // Apply color replacements
            for (const auto& replacement : replacements->second) {
                // Simple color matching (you might want more sophisticated color matching)
                if ((pixel & 0xFFFFFF00) == (replacement.fromColor & 0xFFFFFF00)) {
                    // Preserve alpha, replace RGB
                    uint8_t alpha = (pixel & 0xFF);
                    row[x] = (replacement.toColor & 0xFFFFFF00) | alpha;
                    break;
                }
            }
        }
    }
}

// Lottie instance wrapper
struct LottieInstance {
    std::shared_ptr<Animation> animation;
    int fitzModifier;
    size_t width;
    size_t height;
    size_t frameCount;
    double frameRate;
    
    LottieInstance(std::shared_ptr<Animation> anim, int fitz) 
        : animation(anim), fitzModifier(fitz) {
        if (animation) {
            animation->size(width, height);
            frameCount = animation->totalFrame();
            frameRate = animation->frameRate();
        }
    }
};

LottieInstanceRef lottie_instance_create(const char* jsonData, int size, int fitzModifier) {
    if (!jsonData || size <= 0) {
        return nullptr;
    }
    
    // Copy JSON into a string
    std::string data(jsonData, size);
    
    // Generate a unique cache key
    static std::atomic<uint64_t> counter{0};
    uint64_t id = counter.fetch_add(1);
    std::string cacheKey = "lottie_" + std::to_string(id);
    
    // Load animation
    auto anim = Animation::loadFromData(data, cacheKey);
    if (!anim) {
        return nullptr;
    }
    
    // Convert unique_ptr to shared_ptr
    std::shared_ptr<Animation> sharedAnim(anim.release());
    
    // Create instance wrapper
    auto instance = new LottieInstance(sharedAnim, fitzModifier);
    return instance;
}

void lottie_instance_render_frame(LottieInstanceRef ref,
                                  int frameNumber,
                                  uint8_t* bufferRGBA,
                                  int width,
                                  int height,
                                  int bytesPerRow) {
    if (!ref || !bufferRGBA) return;
    
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    if (!instance || !instance->animation) return;
    
    // Ensure we have valid dimensions
    if (width <= 0 || height <= 0) return;
    if (bytesPerRow < width * 4) {
        bytesPerRow = width * 4;
    }
    
    // Create surface - rlottie expects RGBA format
    // Note: rlottie's Surface expects uint32_t* with RGBA layout
    uint32_t* buffer32 = reinterpret_cast<uint32_t*>(bufferRGBA);
    
    // Clear buffer first (important for transparency)
    memset(bufferRGBA, 0, height * bytesPerRow);
    
    // Create surface with proper stride
    Surface surface(buffer32,
                    static_cast<size_t>(width),
                    static_cast<size_t>(height),
                    static_cast<size_t>(bytesPerRow));
    
    // Render frame
    instance->animation->renderSync(static_cast<size_t>(frameNumber), surface);
    
    // rlottie renders pixels - need to convert to ARGB (premultiplied) for iOS
    // Try different conversion based on actual rlottie output format
    convertBGRAToARGBPremultiplied(bufferRGBA, width, height, bytesPerRow);
    
    // Apply Fitz modifier if needed (after conversion)
    if (instance->fitzModifier != FitzNone) {
        applyFitzModifier(bufferRGBA, width, height, bytesPerRow, instance->fitzModifier);
    }
}

// Convert to ARGB (premultiplied) - optimized C++ implementation
// rlottie's Surface writes pixels as uint32_t
// Based on testing, rlottie appears to output in RGBA byte order: [R, G, B, A]
// We need ARGB (premultiplied) for iOS CGImage with premultipliedFirst
// ARGB in 32-bit word (0xAARRGGBB) is stored as [BB, GG, RR, AA] in little-endian memory
static void convertBGRAToARGBPremultiplied(uint8_t* buffer, int width, int height, int bytesPerRow) {
    // Process pixels byte-by-byte to handle RGBA format correctly
    for (int y = 0; y < height; y++) {
        uint8_t* row = buffer + y * bytesPerRow;
        for (int x = 0; x < width; x++) {
            uint8_t* pixel = row + x * 4;
            
            // rlottie outputs RGBA format as bytes: [R, G, B, A]
            uint8_t r = pixel[0];
            uint8_t g = pixel[1];
            uint8_t b = pixel[2];
            uint8_t a = pixel[3];
            
            // Premultiply alpha for proper blending
            if (a == 0) {
                // Transparent pixel
                pixel[0] = 0;
                pixel[1] = 0;
                pixel[2] = 0;
                pixel[3] = 0;
                continue;
            }
            
            float alpha = a / 255.0f;
            uint8_t rPremult = static_cast<uint8_t>(r * alpha + 0.5f);
            uint8_t gPremult = static_cast<uint8_t>(g * alpha + 0.5f);
            uint8_t bPremult = static_cast<uint8_t>(b * alpha + 0.5f);
            
            // Store as ARGB for premultipliedFirst
            // In 32-bit word: 0xAARRGGBB
            // In little-endian memory (bytes): [BB, GG, RR, AA]
            pixel[0] = bPremult;  // B -> first byte (little endian)
            pixel[1] = gPremult;  // G
            pixel[2] = rPremult;  // R
            pixel[3] = a;         // A -> last byte
        }
    }
}

int lottie_instance_frame_count(LottieInstanceRef ref) {
    if (!ref) return 0;
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    return instance ? static_cast<int>(instance->frameCount) : 0;
}

int lottie_instance_width(LottieInstanceRef ref) {
    if (!ref) return 0;
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    return instance ? static_cast<int>(instance->width) : 0;
}

int lottie_instance_height(LottieInstanceRef ref) {
    if (!ref) return 0;
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    return instance ? static_cast<int>(instance->height) : 0;
}

double lottie_instance_frame_rate(LottieInstanceRef ref) {
    if (!ref) return 0.0;
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    return instance ? instance->frameRate : 0.0;
}

void lottie_instance_destroy(LottieInstanceRef ref) {
    if (!ref) return;
    auto instance = reinterpret_cast<LottieInstance*>(ref);
    delete instance;
}

