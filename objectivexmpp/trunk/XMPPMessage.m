//
//  XMPPMessage.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "XMPPMessage.h"

NSString *const XMPPStanzaMessageElementName = @"message";
NSString *const XMPPStanzaIQElementName = @"iq";
NSString *const XMPPStanzaPresenceElementName = @"presence";

NSString *const XMPPStreamFeaturesLocalElementName = @"features";

NSXMLElement *XMPPMessageWithBody(NSString *bodyValue) {
	NSXMLElement *message = [NSXMLElement elementWithName:XMPPStanzaMessageElementName];
	[message addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"chat"]];
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:bodyValue];
	[message addChild:body];
	
	return message;
}

BOOL XMPPMessageIsComposing(NSXMLElement *element) {
	NSCParameterAssert([[element name] caseInsensitiveCompare:XMPPStanzaMessageElementName] == NSOrderedSame);
	
	NSDictionary *prefixMapping = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"http://jabber.org/protocol/chatstates", @"a",
								   nil];
	
	NSError *composingXPathError = nil;
	NSArray *elements = [(id)element nodesForXPath:@"/message/a:composing" namespaces:prefixMapping error:&composingXPathError];
	
	return ([elements count] == 1);
}
