
#import "DDXMLNode+Private.h"
#import "DDXMLElement+Private.h"
#import "DDXMLDocument+Private.h"

// We can't rely solely on NSAssert, because many developers disable them for release builds.
// Our API contract requires us to keep these assertions intact.

#define DDCheck(condition, desc, ...)  { if(!(condition)) { [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(desc), ##__VA_ARGS__]; } }
