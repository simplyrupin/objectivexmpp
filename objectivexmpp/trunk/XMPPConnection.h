//
//  XMPPConnection.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkConnection.h"

@class NSXMLElement;

@protocol XMPPConnectionDelegate, XMPPConnectionDataSource;

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
+ (NSString *)clientStreamVersion;

/*!
	@brief
	These addresses are specifically strings, the contain the JID for each endpoint.
 */
@property (readwrite, copy) NSString *localAddress, *peerAddress;

/*!
	
 */
@property (assign) id <XMPPConnectionDelegate, XMPPConnectionDataSource> delegate;

/*! 
	@brief
	Providing a context, you should expect to handle the response.
 
	@detail
	If the connection isn't connected, your element will be enqueued for delivery once connection bookkeeping has been performed.
	
	@result
	The id attribute of the message, allowing you to track a response if appropriate.
 */
- (NSString *)sendElement:(NSXMLElement *)element context:(void *)context;

/*!
	@brief
	This sends a <message/> stanza to the indicated JID
 
	@detail
	This method calls <tt>-sendElement:context:</tt> after wrapping the message for you.
	
	@param |JID|
	If nil this sends the message to the connected endpoint, if [NSNull null] nothing is added.
	
	@result
	The stanza sent, for including in a conversation list.
 */
- (NSXMLElement *)sendMessage:(NSString *)content receiver:(NSString *)JID;

/*!
	@brief
	This sends a subscription IQ to the connected endpoint.
	
	@detail
	The delegate will receive subscription update notifications.
 */
- (void)subscribe:(NSString *)nodeName;

/*!
	@brief
	This sends an unsubscribe IQ to the connected endpoint.
 */
- (void)unsubscribe:(NSString *)nodename;

/*!
	@brief
	Given an IQ element, you'll typically return an awkknowledgement. No other data is included in the stanza.
 */
- (void)awknowledgeElement:(NSXMLElement *)iq;

/*
	Override points for XMPP extensions
 */

/*
	These methods are called first. The default implementations call <tt>-connectionDidReceiveElement:</tt> on self.
 */
- (void)connectionDidReceiveIQ:(NSXMLElement *)iq;
- (void)connectionDidReceiveMessage:(NSXMLElement *)message;
- (void)connectionDidReceivePresence:(NSXMLElement *)presence;

/*!
	@brief
	This forwards the element onto the delegate.
 */
- (void)connectionDidReceiveElement:(NSXMLElement *)element;

@end

/*!
	@brief
	This class doesn't currently specify a separate dataSource, these methods are just separated from the eventing callbacks in the <tt>XMPPConnectionDelegate</tt>.
 */
@protocol XMPPConnectionDataSource <NSObject>

 @optional

/*!
	@brief
	After both streams open, the specification dictates that we send a <features xmlns="http://etherx.jabber.org/streams"/> element.
	Because this is where custom implementations my want to customise a response, we consult the datasource.
 */
- (NSArray *)connectionWillSendStreamFeatures:(XMPPConnection *)layer;

@end

@protocol XMPPConnectionDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@brief
	This is called with an <iq/> element.
 */
- (void)connection:(XMPPConnection *)layer didReceiveIQ:(NSXMLElement *)iq;

/*!
	@brief
	This is called with a <message/> element.
 */
- (void)connection:(XMPPConnection *)layer didReceiveMessage:(NSXMLElement *)message;

/*!
	@brief
	This is called with a <presence/> element.
 */
- (void)connection:(XMPPConnection *)layer didReceivePresence:(NSXMLElement *)presence;

/*!
	@brief
	This is a fall through and is only called if the specific stanza handling methods aren't implemented.
 */
- (void)connection:(XMPPConnection *)layer didReceiveElement:(NSXMLElement *)element;

@end
