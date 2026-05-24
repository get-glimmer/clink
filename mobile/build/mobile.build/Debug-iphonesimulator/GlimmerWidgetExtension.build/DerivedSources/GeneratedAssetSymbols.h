#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "glitchLid" asset catalog image resource.
static NSString * const ACImageNameGlitchLid AC_SWIFT_PRIVATE = @"glitchLid";

/// The "glitchLid 1" asset catalog image resource.
static NSString * const ACImageNameGlitchLid1 AC_SWIFT_PRIVATE = @"glitchLid 1";

/// The "jarBase" asset catalog image resource.
static NSString * const ACImageNameJarBase AC_SWIFT_PRIVATE = @"jarBase";

#undef AC_SWIFT_PRIVATE
