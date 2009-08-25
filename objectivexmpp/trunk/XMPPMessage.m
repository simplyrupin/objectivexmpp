//
//  XMPPMessage.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "XMPPMessage.h"

NSString *const XMPPStreamFeaturesLocalElementName = @"features";

NSString *const XMPPStreamMessageElementName = @"message";
NSString *const XMPPStreamIQElementName = @"iq";
NSString *const XMPPStreamPresenceElementName = @"presence";

BOOL XMPPMessageIsComposing(NSXMLElement *element) {
	NSCParameterAssert([[element name] caseInsensitiveCompare:XMPPStreamMessageElementName] == NSOrderedSame);
	
	NSDictionary *prefixMapping = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"http://jabber.org/protocol/chatstates", @"a",
								   nil];
	
	NSError *composingXPathError = nil;
	NSArray *elements = [element nodesForXPath:@"/message/a:composing" namespaces:prefixMapping error:&composingXPathError];
	
	return ([elements count] == 1);
}
