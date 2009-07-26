//
//  XMPPConnection.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkConnection.h"

@class NSXMLElement;

@protocol XMPPConnectionDelegate;

/*!
	@brief
	This class implements XML chunk messaging with an XMPP endpoint for both server and serverless messaging.
 
	@detail
	You can capture all XML element writes by overriding <tt>-performWrite:forTag:withTimeout:</tt>, except for the processing instruction, the opening stream tag and the closing stream tag.
 */
@interface XMPPConnection : AFNetworkConnection <AFConnectionLayer> {
	NSXMLElement *_rootStreamElement;
	
	NSString *_local;
	NSUInteger _receiveState;
	NSMutableData *_receiveBuffer;
	
	NSString *_peer;
	NSInteger _sendState;
	NSMutableArray *_queuedMessages;
	
	NSTimer *_keepAliveTimer;
}

/*!
	@brief
	The connection compatability version
 */
+ (NSString *)connectionCompatabilityVersion;

/*!
	
 */
@property (copy) NSString *peer, *local;

/*!
	
 */
@property (assign) id <XMPPConnectionDelegate> delegate;

/*!
	@brief
	XMPPConnection will attempt to handle the response.
 
	@result
	See <tt>-sendElement:forTag:</tt>
 */
- (NSString *)sendElement:(NSXMLElement *)element;

/*! 
	@brief
	You should expect to handle the response.
 
	@result
	The id attribute of the message, allowing you to track the response.
 */
- (NSString *)sendElement:(NSXMLElement *)element forTag:(NSInteger)tag;

/*!
	@brief
	This sends a message stanza to the indicated JID
 
	@param |JID|
	If nil this sends the message to the connected endpoint.
 */
- (NSXMLElement *)sendMessage:(NSString *)content to:(NSString *)JID;

/*!
	@brief
	This sends a subscription IQ to the connected endpoint.
 
	@detail
	The delegate will receive subsctiption update notifications.
 */
- (void)subscribe:(NSString *)nodeName;

/*!
	@brief
	This sends an unsubscribe IQ to the connected endpoint.
 */
- (void)unsubscribe:(NSString *)nodename;

/*!
	@brief
	Given an IQ element, you'll typically return a response.
	This is simply an awknowledgement, no other data is included in the stanza.
 */
- (void)awknowledgeElement:(NSXMLElement *)iq;

/*
 * Note: override points for XMPP extensions
 */

- (void)connectionDidReceiveElement:(NSXMLElement *)element; // Note: general override point, this where the element pattern matching is performed to call the specific handler methods

- (void)connectionDidReceiveIQ:(NSXMLElement *)iq;
- (void)connectionDidReceiveMessage:(NSXMLElement *)message;
- (void)connectionDidReceivePresence:(NSXMLElement *)presence; // Note: these attempt to call the specific delegate method and fallback to the general one

@end

@protocol XMPPConnectionDelegate <AFConnectionLayerControlDelegate>

 @optional

/**
 * These methods are called after an instance of their respective stanza is received.
**/
- (void)connection:(XMPPConnection *)layer didReceiveIQ:(NSXMLElement *)iq;
- (void)connection:(XMPPConnection *)layer didReceiveMessage:(NSXMLElement *)message;
- (void)connection:(XMPPConnection *)layer didReceivePresence:(NSXMLElement *)presence;

/*!
	@brief
	This is a fall through and is only called if the specific stanza handling methods aren't implemented.
 */
- (void)connection:(XMPPConnection *)layer didReceiveElement:(NSXMLElement *)element;

@end
