//
//  _XMPPForwarder.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "_XMPPForwarder.h"

#import "XMPPMessage.h"

@implementation _XMPPForwarder

+ (void)forwardElement:(NSXMLElement *)element from:(XMPPConnection *)connection to:(id <XMPPConnectionDelegate>)target {
	if ([[element name] isEqualToString:XMPPStanzaIQElementName] && [target respondsToSelector:@selector(connection:didReceiveIQ:)]) {
		[target connection:connection didReceiveIQ:element];
	} else if ([[element name] isEqualToString:XMPPStanzaMessageElementName] && [target respondsToSelector:@selector(connection:didReceiveMessage:)]) {
		[target connection:connection didReceiveMessage:element];
	} else if ([[element name] isEqualToString:XMPPStanzaPresenceElementName] && [target respondsToSelector:@selector(connection:didReceivePresence:)]) {
		[target connection:connection didReceivePresence:element];
	} else if ([target respondsToSelector:@selector(connection:didReceiveElement:)]) {
		[target connection:connection didReceiveElement:element];
	}
}

@end
