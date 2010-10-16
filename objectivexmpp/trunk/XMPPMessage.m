//
//  XMPPMessage.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "XMPPMessage.h"

#import "NSXMLNode+AFXMPPAdditions.h"

NSString *const AFXMPPStanzaMessageElementName = @"message";
NSString *const AFXMPPStanzaIQElementName = @"iq";
NSString *const AFXMPPStanzaPresenceElementName = @"presence";

NSString *const AFXMPPStreamFeaturesLocalElementName = @"features";

NSXMLElement *AFXMPPMessageWithBody(NSString *bodyValue) {
	NSXMLElement *message = [NSXMLElement elementWithName:AFXMPPStanzaMessageElementName];
	[message addAttribute:[NSXMLNode attributeWithName:@"type" stringValue:@"chat"]];
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:bodyValue];
	[message addChild:body];
	
	return message;
}

BOOL AFXMPPMessageIsComposing(NSXMLElement *element) {
	if ([[element name] caseInsensitiveCompare:AFXMPPStanzaMessageElementName] != NSOrderedSame) return NO;
	
	NSDictionary *prefixMapping = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"http://jabber.org/protocol/chatstates", @"a",
								   nil];
	
	NSError *composingXPathError = nil;
	NSArray *elements = [(id)element nodesForXPath:@"/message/a:composing" namespaces:prefixMapping error:&composingXPathError];
	
	return ([elements count] == 1);
}
