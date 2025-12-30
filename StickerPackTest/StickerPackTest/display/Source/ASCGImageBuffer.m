//
//  ASCGImageBuffer.m
//  Simple replacement for AsyncDisplayKit's ASCGImageBuffer
//

#import "ASCGImageBuffer.h"

@implementation ASCGImageBuffer {
    BOOL _createdData;
    NSUInteger _length;
    void *_mutableBytes;
}

- (instancetype)initWithLength:(NSUInteger)length {
    if (self = [super init]) {
        _length = length;
        _mutableBytes = calloc(1, length); // Zero-filled buffer
        if (_mutableBytes == NULL) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (!_createdData && _mutableBytes != NULL) {
        free(_mutableBytes);
    }
}

- (CGDataProviderRef)createDataProviderAndInvalidate {
    NSAssert(!_createdData, @"Should not create data provider from buffer multiple times.");
    _createdData = YES;
    
    // Wrap in an NSData with custom deallocator
    NSData *data = [[NSData alloc] initWithBytesNoCopy:_mutableBytes 
                                                  length:_length 
                                            deallocator:^(void *bytes, NSUInteger length) {
        free(bytes);
    }];
    
    return CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
}

@end

