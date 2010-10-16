//
//  _XMPPForwarder.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "_AFXMPPForwarder.h"

#import "XMPPMessage.h"

@implementation _AFXMPPForwarder

+ (void)forwardElement:(NSXMLElement *)element from:(AFXMPPConnection *)connection to:(id <AFXMPPConnectionDelegate>)target {
	if ([[element name] isEqualToString:AFXMPPStanzaIQElementName] && [target respondsToSelector:@selector(connection:didReceiveIQ:)]) {
		[target connection:connection didReceiveIQ:element];
	} else if ([[element name] isEqualToString:AFXMPPStanzaMessageElementName] && [target respondsToSelector:@selector(connection:didReceiveMessage:)]) {
		[target connection:connection didReceiveMessage:element];
	} else if ([[element name] isEqualToString:AFXMPPStanzaPresenceElementName] && [target respondsToSelector:@selector(connection:didReceivePresence:)]) {
		[target connection:connection didReceivePresence:element];
	} else if ([target respondsToSelector:@selector(connection:didReceiveElement:)]) {
		[target connection:connection didReceiveElement:element];
	}
}

@end
