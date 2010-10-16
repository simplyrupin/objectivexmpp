//
//  _XMPPForwarder.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AFXMPPConnection.h"

/*!
	\brief
	This class introspects an element and attempts to forward it to an appropriate handler method.
 */
@interface _AFXMPPForwarder : NSProxy

+ (void)forwardElement:(NSXMLElement *)element from:(AFXMPPConnection *)connection to:(id <AFXMPPConnectionDelegate>)target;

@end
