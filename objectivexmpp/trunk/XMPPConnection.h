//
//  XMPPConnection.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkConnection.h"

@class CXMLElement;

@protocol XMPPConnectionDelegate;

extern NSString *const XMPPAuthenticationSchemePLAIN;
extern NSString *const XMPPAuthenticationSchemeDigestMD5;

/*!
	@brief
	This class implements XML chunk messaging with an XMPP endpoint.
	It works for both server and serverless messaging.
 */
@interface XMPPConnection : AFNetworkConnection <AFConnectionLayer> {
	NSString *_peer, *_local;
	
	NSInteger sendState, receiveState;
	NSMutableData *_connectionBuffer;
	NSMutableArray *_queuedMessages;
	
	NSString *_authUsername, *_authResource, *_tempPassword;
	BOOL _authenticated;
	
	CXMLElement *_rootElement;
	
	NSTimer *keepAliveTimer;
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

- (BOOL)supportsInBandRegistration;
- (void)registerUser:(NSString *)username withPassword:(NSString *)password;

- (BOOL)supportsAuthentication:(NSString *)type;
- (void)authenticateUser:(NSString *)username withPassword:(NSString *)password resource:(NSString *)resource;

@property (readonly, assign, getter=isAuthenticated) BOOL authenticated;
@property (readonly, copy) NSString *authenticatedUsername, *authenticatedResource;

/*!
	@brief
	XMPPConnection will attempt to handle the response.
 
	@result
	See <tt>-sendElement:forTag:</tt>
 */
- (NSString *)sendElement:(CXMLElement *)element;

/*! 
	@brief
	You should expect to handle the response.
 
	@result
	The id attribute of the message, allowing you to track the response.
 */
- (NSString *)sendElement:(CXMLElement *)element forTag:(NSInteger)tag;

/*!
	@brief
	This sends a message stanza to the indicated JID
 
	@param |JID|
	If nil this sends the message to the connected endpoint.
 */
- (CXMLElement *)sendMessage:(NSString *)content to:(NSString *)JID;

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
- (void)awknowledgeElement:(CXMLElement *)iq;

/*
 * Note: override points for XMPP extensions
 */

- (void)connectionDidReceiveElement:(CXMLElement *)element; // Note: general override point, this where the element pattern matching is performed to call the specific handler methods

- (void)connectionDidReceiveIQ:(CXMLElement *)iq;
- (void)connectionDidReceiveMessage:(CXMLElement *)message;
- (void)connectionDidReceivePresence:(CXMLElement *)presence; // Note: these attempt to call the specific delegate method and fallback to the general one

@end

@protocol XMPPConnectionDelegate <AFConnectionLayerControlDelegate>

 @optional

/**
 * This method is called after registration of a new user has successfully finished.
 * If registration fails for some reason, the connection:didNotRegister: method will be called instead.
**/
- (void)connectionDidRegister:(XMPPConnection *)sender;

/**
 * This method is called if registration fails.
**/
- (void)connection:(XMPPConnection *)sender didNotRegister:(CXMLElement *)errorElement;

/**
 * This method is called after authentication has successfully finished.
 * If authentication fails for some reason, the connection:didNotAuthenticate: method will be called instead.
**/
- (void)connectionDidAuthenticate:(XMPPConnection *)sender;

/**
 * This method is called if authentication fails.
**/
- (void)connection:(XMPPConnection *)sender didNotAuthenticate:(CXMLElement *)errorElement;

/**
 * These methods are called after an instance of their respective stanza is received.
**/
- (void)connection:(XMPPConnection *)layer didReceiveIQ:(CXMLElement *)iq;
- (void)connection:(XMPPConnection *)layer didReceiveMessage:(CXMLElement *)message;
- (void)connection:(XMPPConnection *)layer didReceivePresence:(CXMLElement *)presence;

/*!
	@brief
	This is a fall through and is only called if the specific stanza handling methods aren't implemented.
 */
- (void)connection:(XMPPConnection *)layer didReceiveElement:(CXMLElement *)element;

@end
