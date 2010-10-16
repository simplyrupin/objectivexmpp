//
//  XMPPServer.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/CoreNetworking.h"
#import "ObjectiveXMPP/AFXMPPConnection.h"

@class NSXMLElement;
@class AFXMPPConnection;

@protocol AFXMPPServerDelegate;

@interface AFXMPPServer : AFNetworkServer {
 @private
	NSString *_hostnode;
	
	NSMutableDictionary *_connectedNodes;
}

@property (assign) id <AFXMPPServerDelegate> delegate;

@property (copy) NSString *hostnode;

@property (readonly, retain) NSDictionary *connectedNodes;

@end

/*!
	\brief
	XMPPConnectionDelegate methods that are implemented in the server, are forwarded to it's delegate if implemented.
 */
@protocol AFXMPPServerDelegate <AFNetworkServerDelegate, AFXMPPConnectionDelegate>

 @optional

/*!
	\brief
	Assumes YES if unimplemented.
 */
- (BOOL)server:(AFXMPPServer *)server shouldForwardMessage:(NSXMLElement *)message fromNode:(NSString *)JID toNode:(NSString *)JID;

@end
