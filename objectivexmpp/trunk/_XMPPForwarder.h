//
//  _XMPPForwarder.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "XMPPConnection.h"

/*!
	@brief
	This class introspects an element and attempts to forward it to an appropriate handler method.
 */
@interface _XMPPForwarder : NSProxy

+ (void)forwardElement:(NSXMLElement *)element from:(XMPPConnection *)connection to:(id <XMPPConnectionDelegate>)target;

@end
