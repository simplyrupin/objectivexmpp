//
//  XMPPServer.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkServer.h"

@class DDXMLElement;
@class XMPPConnection;

@protocol XMPPServerDelegate;

@interface XMPPServer : AFNetworkServer {
	NSString *_hostnode;
	
	NSMutableDictionary *_connectedNodes, *_nodeSubscriptions;
}

@property (assign) id <XMPPServerDelegate> delegate;

@property (copy) NSString *hostnode;

@property (readonly, retain) NSDictionary *connectedNodes;

- (void)notifySubscribersForNode:(NSString *)nodeName withPayload:(NSArray *)itemElements;

@end

@protocol XMPPServerDelegate <AFNetworkServerDelegate>

 @optional

/*!
	@brief
	This is included for P2P XMPP servers, where the endpoint/JID is the advertised service name
 */
- (void)server:(XMPPServer *)server assignConnectionPeer:(XMPPConnection *)connection;

/*!
	@brief
 */
- (BOOL)server:(XMPPServer *)server shouldForwardMessage:(DDXMLElement *)message fromNode:(NSString *)JID toNode:(NSString *)JID; // Note: assumes YES if unimplemented

@end
