#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "NSStringPunycodeAdditions.h"
#import "WebNSURLExtras.h"

FOUNDATION_EXPORT double Punycode_CocoaVersionNumber;
FOUNDATION_EXPORT const unsigned char Punycode_CocoaVersionString[];

