//
//  RLottieBridge.h
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//

#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void* RLottieAnimationRef;

/// Load animation from data (JSON/TGS)
RLottieAnimationRef rlottie_load_animation(const char* jsonData, int size);

/// Render frame into RGBA buffer
void rlottie_render_frame(RLottieAnimationRef anim,
						  int frameNumber,
						  uint8_t* bufferRGBA,
						  int width,
						  int height);

/// Get total frame count
int rlottie_frame_count(RLottieAnimationRef anim);

/// Destroy animation
void rlottie_destroy(RLottieAnimationRef anim);

#ifdef __cplusplus
}
#endif
