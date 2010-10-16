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
#import "_XMPPForwarder.h"

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

NSSTRING_CONTEXT(XMPPConnectionFeaturesContext);

NSSTRING_CONTEXT(XMPPConnectionMessageContext);
NSSTRING_CONTEXT(XMPPConnectionPubSubContext);

enum {
	StreamNotConnected	= 0,
	StreamConnecting	= 1UL << 0,
	StreamNegotiating	= 1UL << 1,
	StreamStartTLS		= 1UL << 2,
	StreamConnected		= 1UL << 3,
	StreamClosing		= 1UL << 4,
	StreamClosed		= 1UL << 5,
};

#pragma mark -

@interface XMPPConnection ()
@property (retain) NSXMLElement *receivedStreamElement, *receivedFeatures;
@property (retain) NSMutableArray *queuedMessages;
@property (retain) NSTimer *keepAliveTimer;
@end

@interface XMPPConnection (Private)
- (void)_streamDidOpen;
- (void)_streamDidClose;
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
@end

#pragma mark -

@implementation XMPPConnection

@dynamic delegate;

@synthesize receivedStreamElement=_receivedStreamElement, receivedFeatures=_receivedFeatures;

@synthesize localAddress=_local, peerAddress=_peer;

@synthesize queuedMessages=_queuedMessages;

@synthesize keepAliveTimer=_keepAliveTimer;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (NSString *)serviceDiscoveryType {
	return XMPPServiceDiscoveryType;
}

+ (NSString *)clientStreamVersion {
	return @"1.0";
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
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
#pragma mark Connection

- (void)open {
	if ([self isOpen]) return;
	
	[super open];
}

- (BOOL)isOpen {
	return ((_sendState & StreamConnected) == StreamConnected) && ((_receiveState & StreamConnected) == StreamConnected);
}

- (void)close {
	if ([self isClosed]) return;
	
	[self _sendClosingNegotiation];
}

- (BOOL)isClosed {
	return ((_sendState == StreamClosed) && (_receiveState == StreamClosed));
}

#pragma mark -
#pragma mark Stream

- (NSString *)peerStreamVersion {
	return [[self.receivedStreamElement attributeForName:@"version"] stringValue];
}

#pragma mark -
#pragma mark Writing

- (NSString *)sendElement:(NSXMLElement *)element context:(void *)context {
	return [self _sendElement:element context:context enqueue:YES];
}

- (NSXMLElement *)sendMessage:(NSString *)content receiver:(NSString *)JID {
	NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body" stringValue:content];
	
	NSXMLElement *messageElement = [NSXMLElement elementWithName:XMPPStanzaMessageElementName];
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
	
	NSXMLElement *iqElement = [NSXMLElement elementWithName:XMPPStanzaIQElementName];
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
	NSAssert(([[iq name] caseInsensitiveCompare:XMPPStanzaIQElementName] == NSOrderedSame), ([NSString stringWithFormat:@"%@ cannot awknowledge a stanza name %@", self, [iq name], nil]));
	
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
#pragma mark Reading

- (void)_connectionDidReceiveElement:(NSXMLElement *)element {
	if (_receiveState = StreamConnected) {
		// Note: this doesn't use the _XMPPForwarder since the selectors are different
		if ([[element name] isEqualToString:XMPPStanzaIQElementName]) {
			[self connectionDidReceiveIQ:element];
		} else if ([[element name] isEqualToString:XMPPStanzaMessageElementName]) {
			[self connectionDidReceiveMessage:element];
		} else if ([[element name] isEqualToString:XMPPStanzaPresenceElementName]) {
			[self connectionDidReceivePresence:element];
		} else {
			[self connectionDidReceiveElement:element];
		}
	} else if (_receiveState == StreamNegotiating) {
		_receiveState = StreamConnected;
		
		if ([[element name] caseInsensitiveCompare:@"stream:features"] == NSOrderedSame) {
			self.receivedStreamElement = element;
			[self _streamDidOpen];
		} else {
			[self _connectionDidReceiveElement:element];
		}
	} else if (_receiveState == StreamStartTLS) {
		//[self _handleStartTLSResponse:element]; // The response from our starttls message
		[self doesNotRecognizeSelector:_cmd];
	}
}

- (void)connectionDidReceiveIQ:(NSXMLElement *)iq {
	[self connectionDidReceiveElement:iq];
}

- (void)connectionDidReceiveMessage:(NSXMLElement *)message {
	[self connectionDidReceiveElement:message];
}

- (void)connectionDidReceivePresence:(NSXMLElement *)presence {
	[self connectionDidReceiveElement:presence];
}

- (void)connectionDidReceiveElement:(NSXMLElement *)element {
	[_XMPPForwarder forwardElement:element from:self to:self.delegate];
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
	
	for (AFPacketWrite *queuedPacket in self.queuedMessages) {
		[self performWrite:queuedPacket withTimeout:[queuedPacket duration] context:[queuedPacket context]];
	}
	self.queuedMessages = nil;
	
	[self _performRead];
}

- (void)_streamDidClose {
	if (_receiveState == StreamClosed && _sendState != StreamClosed) {
		[self close];
		return;
	}
	
	if (![self isClosed]) return;
	
	[self.delegate layerDidClose:self];
}

@end

@implementation XMPPConnection (PrivateWriting)

/*
	\brief
	The opening negotiation is covered by RFC3920 §4 [http://xmpp.org/rfcs/rfc3920.html#streams]
 */
- (void)_sendOpeningNegotiation {
	if (_sendState == StreamConnecting) {
		NSString *processingInstruction = @"<?xml version='1.0' encoding='UTF-8'?>";
		[super performWrite:[processingInstruction dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:NULL];
	}
	
	NSMutableString *openingTag = [NSMutableString stringWithString:@"<stream:stream "];
	
	// Note: if we've the receiving party we need to perform version matching, otherwise we advertise our maximum version
	if (_receiveState == StreamConnected) {
		// Note: if the initiating entity didn't include a version, neither do we
		if ([self.receivedStreamElement attributeForName:@"version"] != nil) {
			
		}
		[openingTag appendFormat:@"version='%@' ", nil];
	} else {
		[openingTag appendFormat:@"version='%@' ", [[self class] clientStreamVersion], nil];
	}
	
	if (self.localAddress != nil) {
		// Note:
		// - the 'from' attribute is ignored if inappropriate but my be useful for XEP-0174
		// - the 'from' attribute SHOULD be included by the receiving entity
		[openingTag appendFormat:@"from='%@' ", self.localAddress, nil];
	}
	if (self.peerAddress != nil) {
		[openingTag appendFormat:@"to='%@' ", self.peerAddress, nil];
	}
	
	// Note: we're sending this in response to an incoming connection
	if (_receiveState == StreamConnected) {
		[openingTag appendFormat:@"id='%@' ", [[NSProcessInfo processInfo] globallyUniqueString], nil];
	}
	
	[openingTag appendFormat:@"xmlns='%@' xmlns:stream='%@'>", XMPPNamespaceClientDefaultURI, XMPPNamespaceStreamURI, nil];
	
	[super performWrite:[openingTag dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStartContext];
}

- (void)_sendClosingNegotiation {
	if (_sendState == StreamClosing) return;
	_sendState = StreamClosing;
	
	NSString *closingTag = @"</stream:stream>";
	[super performWrite:[closingTag dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStopContext];
}

- (NSString *)_preprocessStanza:(NSXMLElement *)element {
	NSString *identifier = [[element attributeForName:@"id"] stringValue];
	
	if ([[element name] caseInsensitiveCompare:XMPPStanzaIQElementName] == NSOrderedSame && identifier == nil) {
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
	\brief
	This method should be used for internal writes, since it doesn't check to see if the stream is open.
	External element sends are queued until the stream is opened.
 */
- (NSString *)_sendElement:(NSXMLElement *)element context:(void *)context enqueue:(BOOL)waitUntilOpen {
	NSString *identifier = [self _preprocessStanza:element];
	
	if (![self isOpen] && waitUntilOpen) {
		AFPacketWrite *packet = [[[AFPacketWrite alloc] initWithContext:context timeout:TIMEOUT_WRITE data:[[element XMLString] dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
		[self.queuedMessages addObject:packet];
	} else {
		[self performWrite:element withTimeout:TIMEOUT_WRITE context:context];
	}
	
	return identifier;
}

- (void)_keepAlive:(NSTimer *)timer {	
	[super performWrite:[@" " dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_WRITE context:&XMPPConnectionStreamContext];
}

@end

@implementation XMPPConnection (PrivateReading)

- (void)_readOpeningNegotiation {
	[super performRead:[@">" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_READ_START context:NULL];
}

- (void)_performRead {
	[super performRead:[[[AFXMLElementPacket alloc] initWithStringEncoding:NSUTF8StringEncoding] autorelease] withTimeout:-1 context:NULL];
}

@end

@implementation XMPPConnection (Delegate)

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if (_sendState != StreamNotConnected) {
		[NSException raise:NSInternalInconsistencyException format:@"%@, has already established an XML stream", self, nil];
		return;
	}
	
	_sendState = _receiveState = StreamConnecting;
	
	[self _sendOpeningNegotiation];
	[self _readOpeningNegotiation];
}

// TODO: refactor this to be context based and to pass packets onto the delegate if not handled
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
			self.receivedStreamElement = [xmlDoc rootElement];
			
			[_receiveBuffer release];
			_receiveBuffer = nil;
		}
		
		NSString *fromString = [[self.receivedStreamElement attributeForName:@"from"] stringValue];
		if (fromString != nil) self.peerAddress = fromString;
		
		// Check for RFC compliance
		NSString *streamVersion = [self peerStreamVersion];
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
		_receiveState = StreamClosed;
		[self _streamDidClose];
		
		return;
	}
	
	NSError *parseError = nil;
	NSXMLDocument *stanzaDocument = [[[NSXMLDocument alloc] initWithXMLString:XMLString options:0 error:&parseError] autorelease];
	NSParameterAssert(parseError == nil && stanzaDocument != nil);
	NSXMLElement *stanza = [stanzaDocument rootElement];
	
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
		
		NSXMLElement *features = [NSXMLElement elementWithName:[NSString stringWithFormat:@"%@:%@", @"stream", XMPPStreamFeaturesLocalElementName, nil]];
		if ([self.delegate respondsToSelector:@selector(connectionWillSendStreamFeatures:)]) {
			NSArray *elements = [self.delegate connectionWillSendStreamFeatures:self];
			[features setChildren:elements];
		}
		[self _sendElement:features context:&XMPPConnectionFeaturesContext enqueue:NO];
	} else if (context == &XMPPConnectionPubSubContext) {
		// nop
	} else if (context == &XMPPConnectionMessageContext) {
		// nop
	} else if (context == &XMPPConnectionStopContext) {
		_sendState = StreamClosed;
		[self _streamDidClose];
	} else {
		if ([self.delegate respondsToSelector:_cmd])
			[(id)self.delegate layer:self didWrite:data context:context];
	}
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	if (_receiveState == StreamNegotiating) {
		if ([[error domain] isEqualToString:AFNetworkingErrorDomain] && [error code] == AFNetworkTransportReadTimeoutError) {
			printf("%s, endpoint <stream:features xmlns:stream=\"%s\"> expected but not received, ignoring.\n", [[super description] UTF8String], [XMPPNamespaceStreamURI UTF8String], nil);
			
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
	_sendState = _receiveState = StreamClosed;
	
	self.receivedStreamElement = nil;
	self.receivedFeatures = nil;
	
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
