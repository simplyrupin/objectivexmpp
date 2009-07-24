//
//  XMPPServer.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkServer.h"

@class CXMLElement;
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
 */
- (BOOL)server:(XMPPServer *)server shouldForwardMessage:(CXMLElement *)message fromNode:(NSString *)JID toNode:(NSString *)JID; // Note: assumes YES if unimplemented

@end
