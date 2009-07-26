
#import <Foundation/Foundation.h>
#import <libxml/tree.h>

@interface NSString (DDXMLAdditions)

/*
	@brief
	A typed replacement for -UTF8String.
 */
- (const xmlChar *)xmlChar;

@end
