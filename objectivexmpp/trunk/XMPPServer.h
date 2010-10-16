//
//  XMPPServer.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/CoreNetworking.h"
#import "ObjectiveXMPP/XMPPConnection.h"

@class NSXMLElement;
@class XMPPConnection;

@protocol XMPPServerDelegate;

@interface XMPPServer : AFNetworkServer {
 @private
	NSString *_hostnode;
	
	NSMutableDictionary *_connectedNodes;
	NSMutableDictionary *_nodeSubscriptions;
}

@property (assign) id <XMPPServerDelegate> delegate;

@property (copy) NSString *hostnode;

@property (readonly, retain) NSDictionary *connectedNodes;

/*!
	\brief
	For XEP-0060.
 */
- (void)notifySubscribersForNode:(NSString *)nodeName withPayload:(NSArray *)itemElements;

@end

/*!
	\brief
	XMPPConnectionDelegate methods that are implemented in the server, are forwarded to it's delegate if implemented.
 */
@protocol XMPPServerDelegate <AFNetworkServerDelegate, XMPPConnectionDelegate>

 @optional

/*!
	\brief
	Assumes YES if unimplemented.
 */
- (BOOL)server:(XMPPServer *)server shouldForwardMessage:(NSXMLElement *)message fromNode:(NSString *)JID toNode:(NSString *)JID;

@end
