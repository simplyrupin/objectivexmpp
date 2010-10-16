//
//  AFXMPPServerModule.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 16/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFXMPPServer;
@class AFXMPPConnection;

@interface AFXMPPServerModule : NSObject

/*!
	\brief
	Return YES to indicate that the element has been handled.
 */
- (BOOL)server:(AFXMPPServer *)server shouldProcessElement:(NSXMLElement *)element fromConnection:(AFXMPPConnection *)connection;

@end
