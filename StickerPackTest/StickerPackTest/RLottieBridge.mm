//
//  rlottie_test.mm
//  StickerPackTest
//
//  Created by e.a.kolesnikov on 03.12.2025.
//


#include "RLottieBridge.h"
#include <rlottie.h>
#include <stdint.h>
#include <memory>
#include <string>
#include <atomic>

using namespace rlottie;

// Global atomic counter to generate unique keys
static std::atomic<uint64_t> g_rlottieCounter{0};

RLottieAnimationRef rlottie_load_animation(const char* jsonData, int size) {
	if (!jsonData || size <= 0) {
		return nullptr;
	}

	// Copy JSON into a string
	std::string data(jsonData, size);

	// Generate a UNIQUE cache key for this animation
	uint64_t id = g_rlottieCounter.fetch_add(1);
	std::string cacheKey = "anim_" + std::to_string(id);

	// Load animation with UNIQUE key
	auto anim = Animation::loadFromData(data, cacheKey);

	if (!anim) {
		return nullptr;
	}

	// Disable caching completely — avoids any collisions
//	anim->setCachePolicy(Animation::CachePolicy::kNone);

	// Move into shared_ptr so Swift can manage it
	return new std::shared_ptr<Animation>(anim.release());
}

void rlottie_render_frame(RLottieAnimationRef ref,
						  int frameNumber,
						  uint8_t* bufferRGBA,
						  int width,
						  int height)
{
	if (!ref || !bufferRGBA) return;

	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
	if (!anim || !*anim) return;

	uint32_t* buffer32 = reinterpret_cast<uint32_t*>(bufferRGBA);
	Surface surface(buffer32,
					static_cast<size_t>(width),
					static_cast<size_t>(height),
					static_cast<size_t>(width * 4));

	(*anim)->renderSync(static_cast<size_t>(frameNumber), surface);
}

int rlottie_frame_count(RLottieAnimationRef ref) {
	if (!ref) return 0;

	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
	if (!anim || !*anim) return 0;

	return static_cast<int>((*anim)->totalFrame());
}

void rlottie_destroy(RLottieAnimationRef ref) {
	if (!ref) return;

	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
	delete anim;
}


// RLottieBridge.mm
//#include "RLottieBridge.h"
//#include <rlottie.h>
//#include <stdint.h>
//#include <memory>
//#include <string>
//
//using namespace rlottie;
//
//
//RLottieAnimationRef rlottie_load_animation(const char* jsonData, int size) {
//	if (!jsonData || size <= 0) {
//		return nullptr;
//	}
//	
//	std::string data(jsonData, size);
//	auto anim = Animation::loadFromData(data, "lottie");
//	if (!anim) {
//		return nullptr;
//	}
//	
//	// Convert unique_ptr to shared_ptr by releasing ownership
//	// This is safe because shared_ptr will take ownership and manage the lifetime
//	return new std::shared_ptr<Animation>(anim.release());
//}
//
//void rlottie_render_frame(RLottieAnimationRef ref,
//						  int frameNumber,
//						  uint8_t* bufferRGBA,
//						  int width,
//						  int height)
//{
//	if (!ref || !bufferRGBA) {
//		return;
//	}
//	
//	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
//	if (!anim || !*anim) {
//		return;
//	}
//	
//	// Convert uint8_t* RGBA buffer to uint32_t* for Surface
//	uint32_t* buffer32 = reinterpret_cast<uint32_t*>(bufferRGBA);
//	Surface surface(buffer32, static_cast<size_t>(width), static_cast<size_t>(height), static_cast<size_t>(width * 4));
//	(*anim)->renderSync(static_cast<size_t>(frameNumber), surface);
//}
//
//int rlottie_frame_count(RLottieAnimationRef ref) {
//	if (!ref) {
//		return 0;
//	}
//	
//	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
//	if (!anim || !*anim) {
//		return 0;
//	}
//	
//	return static_cast<int>((*anim)->totalFrame());
//}
//
//void rlottie_destroy(RLottieAnimationRef ref) {
//	if (!ref) {
//		return;
//	}
//	
//	auto anim = reinterpret_cast<std::shared_ptr<Animation>*>(ref);
//	delete anim;
//}
