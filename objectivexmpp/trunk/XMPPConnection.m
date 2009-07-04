//
//  XMPPConnection.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "XMPPConnection.h"

#import "XMPPConstants.h"
#import "XMPPDigestAuthentication.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif
#import "AmberFoundation/AmberFoundation.h"
#import "CoreNetworking/CoreNetworking.h"
#import <libxml/>

NSString *const XMPPAuthenticationSchemePLAIN = @"PLAIN";
NSString *const XMPPAuthenticationSchemeDigestMD5 = @"DIGEST-MD5";

#define DEBUG_SEND
#define DEBUG_RECV

#define TIMEOUT_WRITE         5
#define TIMEOUT_READ_START    5
#define TIMEOUT_READ_STREAM  -1

enum _XMPPConnectionWriteTags {
	XCWriteStartTag,
	XCWriteStreamTag,
	XCWriteStopTag,
};
typedef NSInteger XMPPConnectionWriteStreamTag;

enum _XMPPConnectionReadTags {
	XCReadStartTag = 200,
	XCReadStreamTag,
};
typedef NSInteger XMPPConnectionReadStreamTag;

enum {
	_StreamDisconnected		= 1UL << 0,
	_StreamConnecting		= 1UL << 1,
	_StreamNegotiating		= 1UL << 2,
	_StreamStartTLS			= 1UL << 3,
	_StreamRegistering		= 1UL << 4,
	_StreamAuth1			= 1UL << 5,
	_StreamAuth2			= 1UL << 6,
	_StreamBinding			= 1UL << 7,
	_StreamStartSession		= 1UL << 8,
	_StreamConnected		= 1UL << 9,
	_StreamClosing			= 1UL << 10,
};

#pragma mark -

@interface XMPPConnection ()
@property (readwrite, assign, getter=isAuthenticated) BOOL authenticated;
@property (readwrite, copy) NSString *authenticatedUsername, *authenticatedResource, *temporaryPassword;
- (NSString *)_sendElement:(DDXMLElement *)element tag:(NSInteger)tag;
- (void)performRead;
- (void)_readOpeningNegotiation;
@end

@interface XMPPConnection (Private)
- (void)_streamDidOpen;
- (void)_sendOpeningNegotiation;
- (void)_handleStreamFeatures;
- (void)_handleStartTLSResponse:(DDXMLElement *)response;
- (void)_handleRegistration:(DDXMLElement *)response;
- (void)_handleAuth1:(DDXMLElement *)response;
- (void)_handleAuth2:(DDXMLElement *)response;
- (void)_handleBinding:(DDXMLElement *)response;
- (void)_handleStartSessionResponse:(DDXMLElement *)response;
- (void)_keepAlive:(NSTimer *)timer;
@end

#pragma mark -

@implementation XMPPConnection

@synthesize peer=_peer, local=_local;

@dynamic delegate;

@synthesize authenticatedUsername=_authUsername, authenticatedResource=_authResource, temporaryPassword=_tempPassword;
@synthesize authenticated=_authenticated;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (NSString *)serviceDiscoveryType {
	return XMPPServiceType;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
		
	sendState = receiveState = _StreamDisconnected;	
	
	_connectionBuffer = [[NSMutableData alloc] init];
	
	_queuedMessages = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc {
	[_peer release];
	[_local release];
	
	[_connectionBuffer release];
	[_queuedMessages release];
	
	[_authUsername release];
	[_authResource release];
	[_tempPassword release];
	
	[_rootElement release];
	
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Connection Methods

- (BOOL)open {
	if ([self isOpen]) return YES;
	return [super open];
}

- (BOOL)isOpen {
	if (![super isOpen]) return NO;
	return ((sendState & _StreamConnected) == _StreamConnected) && ((receiveState & _StreamConnected) == _StreamConnected);
}

- (void)close {
	sendState = _StreamClosing;
	
	[super performWrite:[@"</stream:stream>" dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStopTag withTimeout:TIMEOUT_WRITE];
}

- (BOOL)isClosed {
	if (![self.lowerLayer isClosed]) return NO;
	return ((sendState == _StreamDisconnected) && (receiveState == _StreamDisconnected));
}

#pragma mark -
#pragma mark Stream Introspection

- (DDXMLElement *)rootElement {
	return _rootElement;
}

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
 **/
- (NSString *)serverConnectionVersion {
	return [[_rootElement attributeForName:@"version"] stringValue];
}

- (BOOL)supportsInBandRegistration {
	if (![self isOpen]) return NO;
	
	DDXMLElement *features = [_rootElement elementForName:@"stream:features"];
	DDXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
	return (reg != nil);
}

- (void)registerUser:(NSString *)username withPassword:(NSString *)password {
	if (![self isOpen]) return;
	
	// The only proper time to call this method is after we've connected to the server,
	// and exchanged the opening XML stream headers
	if (![self supportsInBandRegistration]) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, this stream doesn't support inband registration", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	DDXMLElement *queryElement = [DDXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
	[queryElement addChild:[DDXMLElement elementWithName:@"username" stringValue:username]];
	[queryElement addChild:[DDXMLElement elementWithName:@"password" stringValue:password]];
	
	DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
	[iqElement addAttributeWithName:@"type" stringValue:@"set"];
	[iqElement addChild:queryElement];
	
	[self sendElement:iqElement forTag:XCWriteStreamTag];
	
	// Update state
	sendState = _StreamRegistering;
}

/**
 * This method checks the stream features of the connected server to determine if plain authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsAuthentication:(NSString *)type {
	// The root element can be properly queried for authentication mechanisms anytime after the stream:features
	// are received, and TLS has been setup (if needed/required)
	if (sendState > _StreamStartTLS) {
#warning the stream:features should be cached and that queried, not the state
		DDXMLElement *features = [_rootElement elementForName:@"stream:features"];
		DDXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSUInteger currentIndex = 0; currentIndex < [mechanisms count]; currentIndex++) {
			NSString *currentMechanism = [[mechanisms objectAtIndex:currentIndex] stringValue];
			if ([currentMechanism isEqualToString:type]) return YES;
		}
	}
	
	return NO;
}

/**
 * This method attempts to sign-in to the server using the given username and password.
 * The result of this action will be returned via the delegate method connection:didReceiveIQ:
 *
 * If the connection is not connected, this method does nothing.
 
 // The only proper time to call this method is after we've connected to the server,
 // and exchanged the opening XML stream headers
 
**/
- (void)authenticateUser:(NSString *)username withPassword:(NSString *)password resource:(NSString *)resource {
	if (![self isOpen]) return;
	
	if ([self supportsAuthentication:XMPPAuthenticationSchemeDigestMD5]) {
		NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";			
		[super performWrite:[auth dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStreamTag withTimeout:TIMEOUT_WRITE];
		
		// Save authentication information
		self.authenticatedUsername = username;
		self.authenticatedResource = resource;
		self.temporaryPassword = password;
		
		// Update state
		sendState = _StreamAuth1;
	} else if ([self supportsAuthentication:XMPPAuthenticationSchemePLAIN]) {
		// From RFC 4616 - PLAIN SASL Mechanism:
		// [authzid] UTF8NUL authcid UTF8NUL passwd
		// 
		// authzid: authorization identity
		// authcid: authentication identity (username)
		// passwd : password for authcid
		
		NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password, nil];
		NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64String];
		
		DDXMLElement *auth = [DDXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
		[auth setStringValue:base64];
		
		[self sendElement:auth forTag:XCWriteStreamTag];
		
		// Save authentication information
		self.authenticatedUsername = username;
		self.authenticatedResource = resource;
		
		// Update state
		sendState = _StreamAuth1;
	} else {
		// The server does not appear to support SASL authentication (at least any type we can use)
		// So we'll revert back to the old fashioned jabber:iq:auth mechanism
		
		NSString *rootID = [[_rootElement attributeForName:@"id"] stringValue];
		NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
		NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
		
		NSString *digest = [[digestData SHA1Hash] hexString];
		
		DDXMLElement *queryElement = [DDXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
		[queryElement addChild:[DDXMLElement elementWithName:@"username" stringValue:username]];
		[queryElement addChild:[DDXMLElement elementWithName:@"digest" stringValue:digest]];
		[queryElement addChild:[DDXMLElement elementWithName:@"resource" stringValue:resource]];
		
		DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
		[iqElement addAttributeWithName:@"type" stringValue:@"set"];
		[iqElement addChild:queryElement];
		
		[self sendElement:iqElement forTag:XCWriteStreamTag];
		
		// Save authentication information
		self.authenticatedUsername = username;
		self.authenticatedResource = resource;
		
		// Update state
		sendState = _StreamAuth1;
	}
}

#pragma mark -
#pragma mark Writing Methods

- (NSString *)sendElement:(DDXMLElement *)element {
	return [self sendElement:element forTag:XCWriteStreamTag];
}

- (NSString *)sendElement:(DDXMLElement *)element forTag:(NSInteger)tag {
	if (![self isOpen]) {
		NSDictionary *queuedElement = [NSDictionary dictionaryWithObjectsAndKeys:
									   element, @"element",
									   [NSNumber numberWithInteger:tag], @"tag",
									   nil];
		
		[_queuedMessages addObject:queuedElement];
		return;
	}
	
	return [self _sendElement:element tag:tag];
}

/*!
	@brief
	This method should be used for internal writes, since it doesn't check to see if the stream is open.
	External element sends are queued until the stream is opened.
 */
- (NSString *)_sendElement:(DDXMLElement *)element tag:(NSInteger)tag {
	NSString *identifier = [[element attributeForName:@"id"] stringValue];
	
	if (identifier == nil) {
		identifier = [[NSProcessInfo processInfo] globallyUniqueString];
		[element addAttributeWithName:@"id" stringValue:identifier];
	}
	
	if ([element attributeForName:@"to"] == nil) {
		[element addAttributeWithName:@"to" stringValue:self.peer];
	}
	
	[self performWrite:element forTag:tag withTimeout:TIMEOUT_WRITE];
	
	return identifier;
}

- (void)awknowledgeElement:(DDXMLElement *)iq {
	NSAssert([[[iq name] lowercaseString] isEqualToString:@"iq"], ([NSString stringWithFormat:@"%@ shouldn't be attempting to awknowledge a stanza name %@", self, [iq name], nil]));
	
	DDXMLElement *response = [DDXMLElement elementWithName:[iq name]];
	[response addAttribute:[iq attributeForName:@"id"]];
}

- (DDXMLElement *)sendMessage:(NSString *)content to:(NSString *)JID {
	DDXMLElement *bodyElement = [DDXMLElement elementWithName:@"body"];
	[bodyElement setStringValue:content];
	
	DDXMLElement *messageElement = [DDXMLElement elementWithName:@"message"];
	if (JID != nil) [messageElement addAttributeWithName:@"to" stringValue:JID];
	[messageElement addChild:bodyElement];
	
	[self sendElement:messageElement];
	
	return messageElement;
}

- (DDXMLElement *)_pubsubElement:(NSString *)method node:(NSString *)name {
	static NSString *const _XMPPNamespacePubSub = @"http://jabber.org/protocol/pubsub";
	
	DDXMLElement *methodElement = [DDXMLElement elementWithName:method];
	[methodElement addAttributeWithName:@"node" stringValue:name];
	[methodElement addAttributeWithName:@"jid" stringValue:self.local];
	
	DDXMLElement *pubsubElement = [DDXMLElement elementWithName:@"pubsub" xmlns:_XMPPNamespacePubSub];
	[pubsubElement addChild:methodElement];
	
	DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
	[iqElement addAttributeWithName:@"type" stringValue:@"set"];
	[iqElement addChild:pubsubElement];
	
	return iqElement;
}

- (void)subscribe:(NSString *)nodeName {
	DDXMLElement *subscribe = [self _pubsubElement:@"subscribe" node:nodeName];
	[self sendElement:subscribe];
}

- (void)unsubscribe:(NSString *)nodename {
	DDXMLElement *unsubscribe = [self _pubsubElement:@"unsubscribe" node:nodename];
	[self sendElement:unsubscribe];
}

- (void)performWrite:(id)element forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	[super performWrite:[[element XMLString] dataUsingEncoding:NSUTF8StringEncoding] forTag:tag withTimeout:duration];
}

#pragma mark -
#pragma mark Reading Methods

- (void)performRead {
	[super performRead:[[[AFXMLElementPacket alloc] initWithStringEncoding:NSUTF8StringEncoding] autorelease] forTag:0 withTimeout:-1];
}

- (void)_readOpeningNegotiation {
	[super performRead:[@">" dataUsingEncoding:NSUTF8StringEncoding] forTag:0 withTimeout:TIMEOUT_READ_START];
}

#pragma mark -

- (void)_connectionDidReceiveElement:(DDXMLElement *)element {
	switch (receiveState) {
		case _StreamConnected:
		{
			[self connectionDidReceiveElement:element];
			break;
		}
		default:
		{
			if (receiveState == _StreamNegotiating) {
				if ([[element name] caseInsensitiveCompare:@"stream:features"] != NSOrderedSame) {
					receiveState = _StreamConnected;
					[self _connectionDidReceiveElement:element];
				}
				
				[element detach];
				[_rootElement setChildren:[NSArray arrayWithObject:element]]; // Note: replace any previously sent features
				[self _handleStreamFeatures];
			} else if (receiveState == _StreamStartTLS) {
				[self _handleStartTLSResponse:element]; // The response from our starttls message
			} else if (receiveState == _StreamRegistering) {
				[self _handleRegistration:element]; // The iq response from our registration request
			} else if (receiveState == _StreamAuth1) {
				[self _handleAuth1:element]; // The challenge response from our auth message
			} else if (receiveState == _StreamAuth2) {
				[self _handleAuth2:element]; // The response from our challenge response
			} else if (receiveState == _StreamBinding) {
				[self _handleBinding:element]; // The response from our binding request
			} else if (receiveState == _StreamStartSession) {
				[self _handleStartSessionResponse:element]; // The response from our start session request
			}
			
			break;
		}
	}
}

- (void)connectionDidReceiveElement:(DDXMLElement *)element {
	if ([[element name] isEqualToString:@"iq"]) {
		[self connectionDidReceiveIQ:element];
	} else if ([[element name] isEqualToString:@"message"]) {
		[self connectionDidReceiveMessage:element];
	} else if ([[element name] isEqualToString:@"presence"]) {
		[self connectionDidReceivePresence:element];
	} else {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveElement:)])
			[self.delegate connection:self didReceiveElement:element];
	}
}

- (void)_forwardElement:(DDXMLElement *)element selector:(SEL)selector {
	if ([self.delegate respondsToSelector:selector]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[(id)self.delegate methodSignatureForSelector:selector]];
		
		[invocation setTarget:self.delegate];
		[invocation setSelector:selector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&element atIndex:3];
		
		[invocation invoke];
	} else {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveElement:)])
			[self.delegate connection:self didReceiveElement:element];
	}
}

- (void)connectionDidReceiveIQ:(DDXMLElement *)iq {
	[self _forwardElement:iq selector:@selector(connection:didReceiveIQ:)];
}

- (void)connectionDidReceiveMessage:(DDXMLElement *)message {
	[self _forwardElement:message selector:@selector(connection:didReceiveMessage:)];
}

- (void)connectionDidReceivePresence:(DDXMLElement *)presence {
	[self _forwardElement:presence selector:@selector(connection:didReceivePresence:)];
}

@end

#pragma mark -

@implementation XMPPConnection (Private)

- (void)_sendOpeningNegotiation {
	if (sendState == _StreamConnecting) {
		// TCP connection was just opened - we need to include the XML instruct
		NSString *s1 = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
		[super performWrite:[s1 dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStartTag withTimeout:TIMEOUT_WRITE];
	}
	
	DDXMLElement *streamElement = [DDXMLElement elementWithName:@"stream:stream" xmlns:@"jabber:client"];
	
	DDXMLNode *streamNamespace = [DDXMLNode namespaceWithName:@"stream" stringValue:@"http://etherx.jabber.org/streams"];
	[streamElement addNamespace:streamNamespace];
	
	NSMutableString *streamElementString = [[streamElement XMLString] mutableCopy];
	[streamElementString replaceOccurrencesOfString:@"</stream:stream>" withString:@"" options:(NSStringCompareOptions)0 range:NSMakeRange(0, [streamElementString length])];
	
	[super performWrite:[streamElementString dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStartTag withTimeout:TIMEOUT_WRITE];
	
	[streamElementString release];
}

- (void)_streamDidOpen {
	// Note: we wait until both XML streams are connected before informing the delegate
	if (![self isOpen]) return;
	
	[self.delegate layerDidOpen:self];
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:self.peer];
	
	for (NSDictionary *queuedMessage in _queuedMessages) {
		[self sendElement:[queuedMessage objectForKey:@"element"] forTag:[[queuedMessage objectForKey:@"tag"] integerValue]];
	}
	[_queuedMessages removeAllObjects];
	
	[self performRead];
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
 **/
- (void)_handleStreamFeatures {
	// Extract the stream features
	DDXMLElement *features = [_rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that DDXMLElement bug you reported to apple (xmlns is required or element won't be found)
	DDXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if (f_starttls != nil) {
		if ([f_starttls elementForName:@"required"] != nil) {
			// TLS is required for this connection
			receiveState = _StreamStartTLS;
			
			NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
			[super performWrite:[starttls dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStreamTag withTimeout:TIMEOUT_WRITE];
			
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that DDXMLElement bug you reported to apple (xmlns is required or element won't be found)
	DDXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if (f_bind != nil) {
		// Binding is required for this connection
		receiveState = _StreamBinding;
		
		if ([self.authenticatedResource length] > 0) {
			// Ask the server to bind the user specified resource
			
			DDXMLElement *resource = [DDXMLElement elementWithName:@"resource"];
			[resource setStringValue:self.authenticatedResource];
			
			DDXMLElement *bind = [DDXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:bind];
			
			[self sendElement:iqElement forTag:XCWriteStreamTag];
		} else {
			// The user didn't specify a resource, so we ask the server to bind one for us
			DDXMLElement *bind = [DDXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:bind];
			
			[self sendElement:iqElement forTag:XCWriteStreamTag];
		}
		
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	receiveState = _StreamConnected;
	[self _streamDidOpen];
	
	if (!self.authenticated) {
		[keepAliveTimer invalidate];
		[keepAliveTimer release];
		
		keepAliveTimer = [[NSTimer scheduledTimerWithTimeInterval:(60.0 * 5) target:self selector:@selector(_keepAlive:) userInfo:nil repeats:YES] retain];
	}
}

- (void)_handleStartTLSResponse:(DDXMLElement *)response {
	// We're expecting a proceed response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if (![[response name] isEqualToString:@"proceed"]) {
		[self close];
		return;
	}
	
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
#warning the settings should come from the response, investigate
	[self startTLS:settings];
	
	// Now we start our negotiation over again...
	[self _sendOpeningNegotiation];
}

/**
 * After the registerUser:withPassword: method is invoked, a registration message is sent to the server.
 * We're waiting for the result from this registration request.
 **/
- (void)_handleRegistration:(DDXMLElement *)response {
	if ([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"]) {
		// Revert back to connected state (from authenticating state)
		receiveState = _StreamConnected;
		
		if ([self.delegate respondsToSelector:@selector(connection:didNotRegister:)])
			[self.delegate connection:self didNotRegister:response];
	} else {
		// Revert back to connected state (from authenticating state)
		receiveState = _StreamConnected;
		
		if ([self.delegate respondsToSelector:@selector(connectionDidRegister:)])
			[self.delegate connectionDidRegister:self];
	}
}

/**
 * After the authenticateUser:withPassword:resource method is invoked, a authentication message is sent to the server.
 * If the server supports digest-md5 sasl authentication, it is used.  Otherwise plain sasl authentication is used,
 * assuming the server supports it.
 * 
 * Now if digest-md5 was used, we sent a challenge request, and we're waiting for a challenge response.
 * If plain sasl was used, we sent our authentication information, and we're waiting for a success response.
 **/
- (void)_handleAuth1:(DDXMLElement *)response {
	if ([self supportsAuthentication:XMPPAuthenticationSchemeDigestMD5]) {
		// We're expecting a challenge response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if (![[response name] isEqualToString:@"challenge"]) {
			// Revert back to connected state (from authenticating state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
				[self.delegate connection:self didNotAuthenticate:response];
		} else {
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
			XMPPDigestAuthentication *auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
			
			// Sometimes the realm isn't specified
			// In this case I believe the realm is implied as the virtual host name
			if ([auth realm] == nil) [auth setRealm:[[super peer] absoluteString]];
			
			// Set digest-uri
			[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", [(id)super peer], nil]];
			
			// Set username and password
			[auth setUsername:self.authenticatedUsername password:self.temporaryPassword];
			
			// Create and send challenge response element
			DDXMLElement *cr = [DDXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			[self sendElement:cr forTag:XCWriteStreamTag];
			
			// Update state
			sendState = _StreamAuth2;
		}
	} else if ([self supportsAuthentication:XMPPAuthenticationSchemePLAIN]) {
		// We're expecting a success response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if (![[response name] isEqualToString:@"success"]) {
			// Revert back to connected state (from authenticating state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
				[self.delegate connection:self didNotAuthenticate:response];
		} else {
			// We are successfully authenticated (via sasl:plain)
			self.authenticated = YES;
			
			// Now we start our negotiation over again...
			[self _sendOpeningNegotiation];
		}
	} else {
		// We used the old fashioned jabber:iq:auth mechanism
		if ([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"]) {
			// Revert back to connected state (from authenticating state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
				[self.delegate connection:self didNotAuthenticate:response];
		} else {
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			self.authenticated = YES;
			
			// Revert back to connected state (from authenticating state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connectionDidAuthenticate:)])
				[self.delegate connectionDidAuthenticate:self];
		}
	}
}

/**
 * This method handles the result of our challenge response we sent in handleAuth1 using digest-md5 sasl.
 **/
- (void)_handleAuth2:(DDXMLElement *)response {
	if ([[response name] isEqualToString:@"challenge"]) {
		XMPPDigestAuthentication *auth = [[[XMPPDigestAuthentication alloc] initWithChallenge:response] autorelease];
		
		if (![auth rspauth]) {
			// We're getting another challenge???
			// I'm not sure what this could possibly be, so for now I'll assume it's a failure
			
			// Revert back to connected state (from authenticating state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
				[self.delegate connection:self didNotAuthenticate:response];
		} else {
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			
			// Create and send empty challenge response element
			DDXMLElement *cr = [DDXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			[self sendElement:cr forTag:XCWriteStreamTag];
			
			// The state remains in STATE_AUTH_2
		}
	} else if ([[response name] isEqualToString:@"success"]) {
		// We are successfully authenticated (via sasl:digest-md5)
		self.authenticated = YES;
		
		// Now we start our negotiation over again...
		[self _sendOpeningNegotiation];
	} else {
		// We received some kind of <failure/> element
		
		// Revert back to connected state (from authenticating state)
		sendState = _StreamConnected;
		
		if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
			[self.delegate connection:self didNotAuthenticate:response];
	}
}

- (void)_handleBinding:(DDXMLElement *)response {
	DDXMLElement *r_bind = [response elementForName:@"bind"];
	DDXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if (r_jid) {
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJID = [r_jid stringValue];
		self.authenticatedResource = [fullJID lastPathComponent];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		DDXMLElement *features = [_rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that DDXMLElement bug you reported to apple (xmlns is required or element won't be found)
		DDXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if (f_session) {
			DDXMLElement *session = [DDXMLElement elementWithName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:session];
			
			[self sendElement:iqElement forTag:XCWriteStreamTag];
			
			// Update state
			sendState = _StreamStartSession;
		} else {
			// Revert back to connected state (from binding state)
			sendState = _StreamConnected;
			
			if ([self.delegate respondsToSelector:@selector(connectionDidAuthenticate:)])
				[self.delegate connectionDidAuthenticate:self];
		}
	} else {
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		DDXMLElement *bind = [DDXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		DDXMLElement *iqElement = [DDXMLElement elementWithName:@"iq"];
		[iqElement addAttributeWithName:@"type" stringValue:@"set"];
		[iqElement addChild:bind];
		
		[self sendElement:iqElement forTag:XCWriteStreamTag];
		
		// The state remains in STATE_BINDING
	}
}

- (void)_handleStartSessionResponse:(DDXMLElement *)response {
	if ([[[response attributeForName:@"type"] stringValue] isEqualToString:@"result"]) {
		// Revert back to connected state (from start session state)
		sendState = _StreamConnected;
		
		if ([self.delegate respondsToSelector:@selector(connectionDidAuthenticate:)])
			[self.delegate connectionDidAuthenticate:self];
	} else {
		// Revert back to connected state (from start session state)
		sendState = _StreamConnected;
		
		if ([self.delegate respondsToSelector:@selector(connection:didNotAuthenticate:)])
			[self.delegate connection:self didNotAuthenticate:response];
	}
}

- (void)_keepAlive:(NSTimer *)timer {
	if (![self isOpen]) {
		[timer invalidate];
		return;
	}
	
	[super performWrite:[@" " dataUsingEncoding:NSUTF8StringEncoding] forTag:XCWriteStreamTag withTimeout:TIMEOUT_WRITE];
}

@end

@implementation XMPPConnection (Delegate)

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if (sendState != _StreamDisconnected) {
		[NSException raise:NSInternalInconsistencyException format:@"%@ has already established an XML stream", self, nil];
		return;
	}
	
	sendState = receiveState = _StreamConnecting;
	
	[self _sendOpeningNegotiation];
	[self _readOpeningNegotiation];
	
	[self.delegate layerDidOpen:self];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data forTag:(NSUInteger)tag {
	if (receiveState == _StreamConnecting) {
		NSString *XMLString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
#ifdef DEBUG_RECV
		NSLog(@"RECV: %@", XMLString, nil);
#endif
		
		// Could be either one of the following:
		// <?xml ...>
		// <stream:stream ...>
		
		[_connectionBuffer appendData:data];
		
		if ([XMLString hasSuffix:@"?>"]) {
			// We read in the <?xml version='1.0'?> line
			// We need to keep reading for the <stream:stream ...> line
			[super performRead:[@">" dataUsingEncoding:NSUTF8StringEncoding] forTag:XCReadStartTag withTimeout:TIMEOUT_READ_START];
			return;
		}
		
		[_connectionBuffer appendData:[@"</stream:stream>" dataUsingEncoding:NSUTF8StringEncoding]];
		
		// At this point we've sent our XML stream header, and we've received the response XML stream header.
		// We save the root element of our stream for future reference.
		// We've kept everything up to this point in our buffer, so all we need to do is close the stream:stream
		// tag to allow us to parse the data as a valid XML document.
		// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
		
		{	
			DDXMLDocument *xmlDoc = [[[DDXMLDocument alloc] initWithData:_connectionBuffer options:0 error:nil] autorelease];
			
			[_rootElement release];
			_rootElement = [[xmlDoc rootElement] retain];
			
			[_connectionBuffer release];
			_connectionBuffer = nil;
		}
		
		NSString *fromString = [[_rootElement attributeForName:@"from"] stringValue];
		if (fromString != nil) self.peer = fromString;
		
		// Check for RFC compliance
		NSString *streamVersion = [self serverConnectionVersion];
		NSComparisonResult versionComparison = [streamVersion compare:@"1.0" options:NSNumericSearch];
		BOOL compliantServer = (streamVersion != nil && (versionComparison == NSOrderedSame || versionComparison == NSOrderedDescending));
		
		if (compliantServer) {
			// Update state - we're now onto stream negotiations
			receiveState = _StreamNegotiating;
			
			// We need to read in the stream features now
			[super performRead:[[[AFXMLElementPacket alloc] initWithStringEncoding:NSUTF8StringEncoding] autorelease] forTag:0 withTimeout:TIMEOUT_READ_START];
		} else {
			// The server isn't RFC compliant, and won't be sending any stream features
			receiveState = _StreamConnected;
			[self _streamDidOpen];
		}
		
		return;
	}
	
	NSString *XMLString = data;
	XMLString = [XMLString stringByTrimmingWhiteSpace];
	
#ifdef DEBUG_RECV
	NSLog(@"RECV: %@", data, nil);
#endif
	
	if ([XMLString hasSuffix:@"</stream:stream>"]) {
		[self close];
		return;
	}
	
	NSError *parseError = nil;
	DDXMLDocument *xmlDoc = [[[DDXMLDocument alloc] initWithXMLString:XMLString options:0 error:&parseError] autorelease];
	NSParameterAssert(parseError == nil && xmlDoc != nil);
	
	[self connectionDidReceiveElement:[xmlDoc rootElement]];
	
	if (![self isOpen]) return;
	[self performRead];
}

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag {
#ifdef DEBUG_SEND
	NSLog(@"SENT: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease], nil);
#endif
	
	if (tag == XCWriteStartTag) {
		sendState = _StreamConnected;
		[self _streamDidOpen];
	} else if (tag == XCWriteStopTag) {
		[self.delegate layerDidClose:self];
	}
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	if (receiveState == _StreamNegotiating) {
		if ([[error domain] isEqualToString:AFNetworkingErrorDomain] && [error code] == AFNetworkTransportReadTimeoutError) {
			NSLog(@"%@, endpoint <stream:features> expected but none received, ignoring.", [super description], nil);
			
			receiveState = _StreamConnected;
			[self _streamDidOpen];
			
			return;
		}
	}
	
	[self.delegate layer:self didReceiveError:error];
}

- (BOOL)socket:(id)socket shouldRemainOpenPendingWrites:(NSUInteger)count {
	return YES;
}

- (void)layer:(id <AFConnectionLayer>)layer didDisconnectWithError:(NSError *)error {
	sendState = receiveState = _StreamDisconnected;
	
	[_rootElement release];
	_rootElement = nil;
	
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
	
	if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
		[self.delegate layer:self didDisconnectWithError:error];
}

@end

#undef DEBUG_SEND
#undef DEBUG_RECV

#undef TIMEOUT_WRITE
#undef TIMEOUT_READ_START
#undef TIMEOUT_READ_STREAM
