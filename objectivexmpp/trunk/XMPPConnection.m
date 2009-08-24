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
#import "XMPPMessage.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif
#import "AmberFoundation/AmberFoundation.h"
#import "CoreNetworking/CoreNetworking.h"

#define DEBUG_SEND 1
#define DEBUG_RECV 1

#define TIMEOUT_WRITE         5
#define TIMEOUT_READ_START    5
#define TIMEOUT_READ_STREAM  -1

NSSTRING_CONTEXT(XMPPConnectionStartContext);
NSSTRING_CONTEXT(XMPPConnectionStreamContext);
NSSTRING_CONTEXT(XMPPConnectionStopContext);

NSSTRING_CONTEXT(XMPPConnectionMessageContext);
NSSTRING_CONTEXT(XMPPConnectionPubSubContext);

enum {
	StreamDisconnected	= 1UL << 0,
	StreamConnecting	= 1UL << 1,
	StreamNegotiating	= 1UL << 2,
	StreamStartTLS		= 1UL << 3,
	StreamConnected		= 1UL << 9,
	StreamClosing		= 1UL << 10,
};

#pragma mark -

@interface XMPPConnection ()
@property (retain) NSXMLElement *rootStreamElement;
@property (retain) NSTimer *keepAliveTimer;
@end

@interface XMPPConnection (PrivateWriting)
- (void)_sendOpeningNegotiation;
- (void)_sendClosingNegotiation;
- (NSString *)_preprocessStanza:(NSXMLElement *)element;
- (NSString *)_sendElement:(NSXMLElement *)element context:(void *)context enqueue:(BOOL)waitUntilOpen;
- (void)_keepAlive:(NSTimer *)timer;
@end

@interface XMPPConnection (PrivateReading)
- (void)_readOpeningNegotiation;
- (void)_performRead;

- (void)_streamDidOpen;
- (void)_handleStartTLSResponse:(NSXMLElement *)response;
@end

#pragma mark -

@implementation XMPPConnection

@synthesize rootStreamElement=_rootStreamElement;

@synthesize localAddress=_local, peerAddress=_peer;
@dynamic delegate;

@synthesize keepAliveTimer=_keepAliveTimer;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (NSString *)serviceDiscoveryType {
	return XMPPServiceDiscoveryType;
}

+ (NSString *)connectionCompatabilityVersion {
	return @"1.0";
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
		
	_sendState = _receiveState = StreamDisconnected;
	
	_receiveBuffer = [[NSMutableData alloc] init];
	
	_queuedMessages = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc {
	[_peer release];
	[_local release];
	
	[_receiveBuffer release];
	[_queuedMessages release];
	
	[_keepAliveTimer invalidate];
	[_keepAliveTimer release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Connection Methods

- (void)open {
	if ([self isOpen]) return;
	
	[super open];
}

- (BOOL)isOpen {
	if (![super isOpen]) return NO;
	return ((_sendState & StreamConnected) == StreamConnected) && ((_receiveState & StreamConnected) == StreamConnected);
}

- (void)close {
	if ([self isClosed]) return;
	
	[self _sendClosingNegotiation];
	_sendState = StreamClosing;
}

- (BOOL)isClosed {
	if (![super isClosed]) return NO;
	return ((_sendState == StreamDisconnected) && (_receiveState == StreamDisconnected));
}

#pragma mark -
#pragma mark Stream Introspection

- (NSString *)serverConnectionVersion {
	return [[self.rootStreamElement attributeForName:@"version"] stringValue];
}

#pragma mark -
#pragma mark Writing Methods

- (void)_sendOpeningNegotiation {
	if (_sendState == StreamConnecting) {
		NSString *processingInstruction = @"<?xml version='1.0' encoding='UTF-8'?>";
		[super performWrite:[processingInstruction dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:NULL];
	}
	
	NSMutableString *openingTag = [NSMutableString stringWithString:@"<stream:stream "];
	if (self.localAddress != nil) {
		[openingTag appendFormat:@"from='%@' ", self.localAddress, nil];
	}
	if (self.peerAddress != nil) {
		[openingTag appendFormat:@"to='%@' ", self.peerAddress, nil];
	}
	[openingTag appendFormat:@"xmlns='jabber:client' xmlns:stream='%@' version='%@'>", XMPPNamespaceStreamURI, [[self class] connectionCompatabilityVersion], nil];
	
	[super performWrite:[openingTag dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStartContext];
}

- (void)_sendClosingNegotiation {
	NSString *closingTag = @"</stream:stream>";
	[super performWrite:[closingTag dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStopContext];
}

- (NSString *)sendElement:(NSXMLElement *)element context:(void *)context {
	return [self _sendElement:element context:context enqueue:YES];
}

- (NSString *)_preprocessStanza:(NSXMLElement *)element {
	NSString *identifier = [[element attributeForName:@"id"] stringValue];
	
	if (identifier == nil) {
		identifier = [[NSProcessInfo processInfo] globallyUniqueString];
		
		NSXMLNode *identifierAttribute = [NSXMLNode attributeWithName:@"id" stringValue:identifier];
		[element addAttribute:identifierAttribute];
	}
	
	if (self.peerAddress != nil && [element attributeForName:@"to"] == nil) {
		[element addAttribute:[NSXMLElement attributeWithName:@"to" stringValue:self.peerAddress]];
	}
	
	return identifier;
}

/*!
	@brief
	This method should be used for internal writes, since it doesn't check to see if the stream is open.
	External element sends are queued until the stream is opened.
 */
- (NSString *)_sendElement:(NSXMLElement *)element context:(void *)context enqueue:(BOOL)waitUntilOpen {
	NSString *identifier = [self _preprocessStanza:element];
	
	if (![self isOpen] && waitUntilOpen) {
		AFPacketWrite *packet = [[[AFPacketWrite alloc] initWithContext:context timeout:TIMEOUT_WRITE data:[[element XMLString] dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
		[_queuedMessages addObject:packet];
	} else {
		[self performWrite:element withTimeout:TIMEOUT_WRITE context:context];
	}
	
	return identifier;
}

- (NSXMLElement *)sendMessage:(NSString *)content receiver:(NSString *)JID {
	NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body" stringValue:content];
	
	NSXMLElement *messageElement = [NSXMLElement elementWithName:@"message"];
	[messageElement addChild:bodyElement];
	
	if (JID != nil) {
		NSXMLElement *toAttribute = [NSXMLElement attributeWithName:@"to" stringValue:JID];
		[messageElement addAttribute:toAttribute];
	}
	
	[self _sendElement:messageElement context:&XMPPConnectionMessageContext enqueue:YES];
	
	return messageElement;
}

- (NSXMLElement *)_pubsubElement:(NSString *)method node:(NSString *)name {
	NSXMLElement *methodElement = [NSXMLElement elementWithName:method];
	[methodElement addAttribute:[NSXMLElement attributeWithName:@"node" stringValue:name]];
	[methodElement addAttribute:[NSXMLElement attributeWithName:@"jid" stringValue:self.localAddress]];
	
	NSXMLElement *pubsubElement = [NSXMLElement elementWithName:@"pubsub" URI:XMPPNamespacePubSubURI];
	[pubsubElement addChild:methodElement];
	
	NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
	[iqElement addAttribute:[NSXMLElement attributeWithName:@"type" stringValue:@"set"]];
	[iqElement addChild:pubsubElement];
	
	return iqElement;
}

- (void)subscribe:(NSString *)nodeName {
	NSXMLElement *subscribe = [self _pubsubElement:@"subscribe" node:nodeName];
	[self sendElement:subscribe context:&XMPPConnectionPubSubContext];
}

- (void)unsubscribe:(NSString *)nodename {
	NSXMLElement *unsubscribe = [self _pubsubElement:@"unsubscribe" node:nodename];
	[self sendElement:unsubscribe context:&XMPPConnectionPubSubContext];
}

- (void)awknowledgeElement:(NSXMLElement *)iq {
	NSAssert([[[iq name] lowercaseString] isEqualToString:@"iq"], ([NSString stringWithFormat:@"%@ shouldn't be attempting to awknowledge a stanza name %@", self, [iq name], nil]));
	
	NSXMLElement *response = [NSXMLElement elementWithName:[iq name]];
	[response addAttribute:[iq attributeForName:@"id"]];
}

- (void)performWrite:(id)element withTimeout:(NSTimeInterval)duration context:(void *)context {
	NSParameterAssert([element isKindOfClass:[AFPacket class]] || [element isKindOfClass:[NSXMLNode class]]);
	
	if ([element isKindOfClass:[NSXMLNode class]])
		[super performWrite:[[element XMLString] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:duration context:context];
	else
		[super performWrite:element withTimeout:duration context:context];
}

#pragma mark -
#pragma mark Reading Methods

- (void)_readOpeningNegotiation {
	[super performRead:[@">" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_READ_START context:NULL];
}

- (void)_performRead {
	[super performRead:[[[AFXMLElementPacket alloc] initWithStringEncoding:NSUTF8StringEncoding] autorelease] withTimeout:-1 context:NULL];
}

#pragma mark -

- (void)_connectionDidReceiveElement:(NSXMLElement *)element {
	if (_receiveState = StreamConnected) {
		[self connectionDidReceiveElement:element];
	} else if (_receiveState == StreamNegotiating) {
		if ([[element name] caseInsensitiveCompare:@"stream:features"] != NSOrderedSame) {
			_receiveState = StreamConnected;
			[self _connectionDidReceiveElement:element];
		}
		
		self.rootStreamElement = element;
	} else if (_receiveState == StreamStartTLS) {
		[self _handleStartTLSResponse:element]; // The response from our starttls message
	}
}

- (void)connectionDidReceiveElement:(NSXMLElement *)element {
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

- (void)_forwardElement:(NSXMLElement *)element selector:(SEL)selector {
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

- (void)connectionDidReceiveIQ:(NSXMLElement *)iq {
	[self _forwardElement:iq selector:@selector(connection:didReceiveIQ:)];
}

- (void)connectionDidReceiveMessage:(NSXMLElement *)message {
	[self _forwardElement:message selector:@selector(connection:didReceiveMessage:)];
}

- (void)connectionDidReceivePresence:(NSXMLElement *)presence {
	[self _forwardElement:presence selector:@selector(connection:didReceivePresence:)];
}

@end

#pragma mark -

@implementation XMPPConnection (Private)

- (void)_streamDidOpen {
	// Note: we wait until both XML streams are connected before informing the delegate
	if (![self isOpen]) return;
	
	[self.delegate layerDidOpen:self];
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:self.peer];
	
	for (NSDictionary *queuedMessage in _queuedMessages) {
		[self sendElement:[queuedMessage objectForKey:@"element"] context:[[queuedMessage objectForKey:@"tag"] pointerValue]];
	}
	[_queuedMessages removeAllObjects];
	
	[self _performRead];
}

- (void)_keepAlive:(NSTimer *)timer {	
	[super performWrite:[@" " dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStreamContext];
}

@end

@implementation XMPPConnection (Delegate)

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if (_sendState != StreamDisconnected) {
		[NSException raise:NSInternalInconsistencyException format:@"%@, has already established an XML stream", self, nil];
		return;
	}
	
	_sendState = _receiveState = StreamConnecting;
	
	[self _sendOpeningNegotiation];
	[self _readOpeningNegotiation];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context {
	if (_receiveState == StreamConnecting) {
		NSString *XMLString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		XMLString = [XMLString stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		
#ifdef DEBUG_RECV
		printf("RECV: %s\n", [XMLString UTF8String], nil);
#endif
		
		// Could be either one of the following:
		// <?xml ...>
		// <stream:stream ...>
		
		[_receiveBuffer appendData:data];
		
		if ([XMLString hasSuffix:@"?>"]) {
			// We read in the <?xml version='1.0'?> line
			// We need to keep reading for the <stream:stream ...> line
			[super performRead:[@">" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_READ_START context:&XMPPConnectionStartContext];
			return;
		}
		
		// At this point we've received the XML stream header, we save the root element of our stream for future reference.
		// We've kept everything up to this point in our buffer, so all we need to do is close the stream:stream tag to allow us to parse the data as a valid XML document.
		// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
		
		{
			[_receiveBuffer appendData:[@"</stream:stream>" dataUsingEncoding:NSUTF8StringEncoding]];
			NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:_receiveBuffer options:0 error:nil] autorelease];
			self.rootStreamElement = [xmlDoc rootElement];
			
			[_receiveBuffer release];
			_receiveBuffer = nil;
		}
		
		NSString *fromString = [[self.rootStreamElement attributeForName:@"from"] stringValue];
		if (fromString != nil) self.peerAddress = fromString;
		
		// Check for RFC compliance
		NSString *streamVersion = [self serverConnectionVersion];
		NSComparisonResult versionComparison = [streamVersion compare:@"1.0" options:NSNumericSearch];
		BOOL compliantServer = (streamVersion != nil && (versionComparison == NSOrderedSame || versionComparison == NSOrderedDescending));
		
		if (compliantServer) {
			// Update state - we're now onto stream negotiations
			_receiveState = StreamNegotiating;
			
			// We need to read in the stream features now
			// It's important this times out so that message sending is enabled on timeout in P2P mode
			[super performRead:[[[AFXMLElementPacket alloc] initWithStringEncoding:NSUTF8StringEncoding] autorelease] withTimeout:TIMEOUT_READ_START context:NULL];
		} else {
			// The server isn't RFC compliant, and won't be sending any stream features
			_receiveState = StreamConnected;
			[self _streamDidOpen];
		}
		
		return;
	}
		
	NSMutableCharacterSet *stripCharacters = [[[NSMutableCharacterSet alloc] init] autorelease];
	[stripCharacters formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
	[stripCharacters formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
	
	NSString *XMLString = data;
	XMLString = [XMLString stringByTrimmingCharactersInSet:stripCharacters];
	
#ifdef DEBUG_RECV
	printf("RECV: %s\n", [data UTF8String], nil);
#endif
		
	if ([XMLString hasSuffix:@"</stream:stream>"]) {
		[self close];
		return;
	}
	
	
	NSError *parseError = nil;
	NSXMLDocument *stanzaDocument = [[[NSXMLDocument alloc] initWithXMLString:XMLString options:0 error:&parseError] autorelease];
	NSParameterAssert(parseError == nil && stanzaDocument != nil);
	NSXMLElement *stanza = [stanzaDocument rootElement];
	
	
	if (_receiveState == StreamNegotiating) {
		if ([[stanza localName] isEqualToString:XMPPStreamFeaturesLocalElementName]) {
			self.rootStreamElement = stanza;
			return;
		}
		
		_receiveState = StreamConnected;
		[self _streamDidOpen];
	}
	
	
	[self connectionDidReceiveElement:stanza];
	
	if (![self isOpen]) return;
	[self _performRead];
}

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context {
#ifdef DEBUG_SEND
	printf("SENT: %s\n", [[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] UTF8String], nil);
#endif
	
	if (context == &XMPPConnectionStartContext) {
		_sendState = StreamConnected;
		[self _streamDidOpen];
	} else if (context == &XMPPConnectionPubSubContext) {
		// nop
	} else if (context == &XMPPConnectionMessageContext) {
		// nop
	} else if (context == &XMPPConnectionStopContext) {
		[self.delegate layerDidClose:self];
	}
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	if (_receiveState == StreamNegotiating) {
		if ([[error domain] isEqualToString:AFNetworkingErrorDomain] && [error code] == AFNetworkTransportReadTimeoutError) {
			NSLog(@"%@, endpoint <stream:features> expected but none received, ignoring.", [super description], nil);
			
			_receiveState = StreamConnected;
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
	_sendState = _receiveState = StreamDisconnected;
	
	self.rootStreamElement = nil;
	
	[self.keepAliveTimer invalidate];
	self.keepAliveTimer = nil;
	
	if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
		[self.delegate layer:self didDisconnectWithError:error];
}

@end

#undef DEBUG_SEND
#undef DEBUG_RECV

#undef TIMEOUT_WRITE
#undef TIMEOUT_READ_START
#undef TIMEOUT_READ_STREAM
