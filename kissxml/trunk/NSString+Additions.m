
#import "NSString+Additions.h"

@implementation NSString (DDXMLAdditions)

- (const xmlChar *)xmlChar
{
	return (const xmlChar *)[self UTF8String];
}

@end
