//
//  LottieInstance.h
//  StickerPackTest
//
//  Created based on Telegram's implementation
//

#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void* LottieInstanceRef;

/// Create Lottie instance from JSON data
/// @param jsonData JSON string data
/// @param size Size of the data
/// @param fitzModifier Fitz modifier type (0 = none, 1-5 = Fitzpatrick scale types)
LottieInstanceRef lottie_instance_create(const char* jsonData, int size, int fitzModifier);

/// Render frame to RGBA buffer
/// @param instance Lottie instance
/// @param frameNumber Frame number to render (0-based)
/// @param bufferRGBA Output RGBA buffer (must be width * height * 4 bytes)
/// @param width Output width
/// @param height Output height
/// @param bytesPerRow Bytes per row (usually width * 4)
void lottie_instance_render_frame(LottieInstanceRef instance,
                                  int frameNumber,
                                  uint8_t* bufferRGBA,
                                  int width,
                                  int height,
                                  int bytesPerRow);

/// Get total frame count
int lottie_instance_frame_count(LottieInstanceRef instance);

/// Get animation width
int lottie_instance_width(LottieInstanceRef instance);

/// Get animation height
int lottie_instance_height(LottieInstanceRef instance);

/// Get frame rate
double lottie_instance_frame_rate(LottieInstanceRef instance);

/// Destroy instance
void lottie_instance_destroy(LottieInstanceRef instance);

#ifdef __cplusplus
}
#endif

