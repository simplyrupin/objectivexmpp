//
//  XMPPConnection.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@class NSXMLElement;

@protocol AFXMPPConnectionDelegate, AFXMPPConnectionDataSource;

/*!
	\brief
	This class implements XML chunk messaging with an XMPP endpoint for client->server, server->server and client->client messaging.
 
	\details
	All XML stanza writes are funneled through <tt>-performWrite:forTag:withTimeout:</tt>, stream setup is handled separately.
 */
@interface AFXMPPConnection : AFNetworkConnection <AFConnectionLayer> {
 @private
	NSXMLElement *_receivedStreamElement;
	NSXMLElement *_receivedFeatures;
	
	NSString *_local;
	NSUInteger _receiveState;
	NSMutableData *_receiveBuffer;
	
	NSString *_peer;
	NSInteger _sendState;
	NSMutableArray *_queuedMessages;
	
	NSTimer *_keepAliveTimer;
}

/*!
	\brief
	The connection compatability version
 */
+ (NSString *)clientStreamVersion;

/*!
	\brief
	These addresses are specifically strings, the contain the JID for each endpoint.
 */
@property (readwrite, copy) NSString *localAddress, *peerAddress;

/*!
	
 */
@property (assign) id <AFXMPPConnectionDelegate, AFXMPPConnectionDataSource> delegate;

/*! 
	\brief
	Providing a context, you should expect to handle the response.
 
	\details
	If the connection isn't connected, your element will be enqueued for delivery once connection bookkeeping has been performed.
	
	\return
	The id attribute of the message, allowing you to track a response if appropriate.
 */
- (NSString *)sendElement:(NSXMLElement *)element context:(void *)context;

/*!
	\brief
	This sends a <message/> stanza to the indicated JID
 
	\details
	This method calls <tt>-sendElement:context:</tt> after wrapping the message for you.
	
	\param JID
	If nil this sends the message to the connected endpoint, if [NSNull null] nothing is added.
	
	\return
	The stanza sent, for including in a conversation list.
 */
- (NSXMLElement *)sendMessage:(NSString *)content receiver:(NSString *)JID;

/*!
	\brief
	This sends a subscription IQ to the connected endpoint.
	
	\details
	The delegate will receive subscription update notifications.
 */
- (void)subscribe:(NSString *)nodeName;

/*!
	\brief
	This sends an unsubscribe IQ to the connected endpoint.
 */
- (void)unsubscribe:(NSString *)nodename;

/*!
	\brief
	Given an IQ element, you'll typically return an awknowledgement. No other data is included in the stanza.
 */
- (void)awknowledgeIQElement:(NSXMLElement *)iq;

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
	\brief
	Forwards the element onto the delegate.
 */
- (void)connectionDidReceiveElement:(NSXMLElement *)element;

@end

/*!
	\brief
	This class doesn't currently specify a separate dataSource, these methods are just separated from the eventing callbacks in the <tt>XMPPConnectionDelegate</tt>.
 */
@protocol AFXMPPConnectionDataSource <NSObject>

 @optional

/*!
	\brief
	After both streams open, the specification dictates that we send a <features xmlns="http://etherx.jabber.org/streams"/> element.
	Clients may wish to customise the response.
 */
- (NSArray *)connectionWillSendStreamFeatures:(AFXMPPConnection *)layer;

@end

@protocol AFXMPPConnectionDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	\brief
	This is called with an <iq/> element.
 */
- (void)connection:(AFXMPPConnection *)layer didReceiveIQ:(NSXMLElement *)iq;

/*!
	\brief
	This is called with a <message/> element.
 */
- (void)connection:(AFXMPPConnection *)layer didReceiveMessage:(NSXMLElement *)message;

/*!
	\brief
	This is called with a <presence/> element.
 */
- (void)connection:(AFXMPPConnection *)layer didReceivePresence:(NSXMLElement *)presence;

/*!
	\brief
	This is a fall through and is only called if the specific stanza handling methods aren't implemented.
 */
- (void)connection:(AFXMPPConnection *)layer didReceiveElement:(NSXMLElement *)element;

@end
