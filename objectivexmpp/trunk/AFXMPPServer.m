//
//  XMPPServer.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFXMPPServer.h"

#import <objc/message.h>
#import "AmberFoundation/AmberFoundation.h"

#import "AFXMPPConstants.h"
#import "AFXMPPMessage.h"
#import "AFXMPPConnection.h"

#import "_AFXMPPForwarder.h"

#warning this class should write to an error log, take a look at ASL

@interface AFXMPPServer ()
@property (readwrite, retain) NSDictionary *connectedNodes;
@end

@implementation AFXMPPServer

@dynamic delegate;

@synthesize hostnode=_hostnode;
@synthesize connectedNodes=_connectedNodes;

+ (id)server {
	return [[[self alloc] initWithEncapsulationClass:[AFXMPPConnection class]] autorelease];
}

- (id)initWithEncapsulationClass:(Class)clientClass {
	self = [super initWithEncapsulationClass:clientClass];
	if (self == nil) return nil;
	
	_connectedNodes = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_hostnode release];
	
	[_connectedNodes release];
	
	[super dealloc];
}

- (AFXMPPConnection *)connectionForNodeName:(NSString *)nodeName {
	return [[self connectedNodes] objectForKey:nodeName];
}

@end

@implementation AFXMPPServer (Delegate)

- (void)layerDidOpen:(id)layer {
	struct objc_super superclass = {
		.receiver = self,
#if TARGET_OS_IPHONE
		.class
#else 
		.super_class
#endif
			= [self superclass],
	};
	(void (*)(struct objc_super *, SEL, id))objc_msgSendSuper(&superclass, _cmd, layer);
	if (![layer isKindOfClass:[AFXMPPConnection class]]) return;
	
	id peerAddress = [layer peerAddress];
	if (peerAddress != nil) [_connectedNodes setObject:layer forKey:peerAddress];
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	[_connectedNodes removeObjectsForKeys:[_connectedNodes allKeysForObject:layer]];
	[layer close];
}

- (void)connection:(AFXMPPConnection *)layer didReceiveIQ:(NSXMLElement *)iq {
#warning pass through the modules
	
	[_AFXMPPForwarder forwardElement:iq from:layer to:[self delegate]];
}

- (void)connection:(AFXMPPConnection *)layer didReceiveMessage:(NSXMLElement *)message {
	NSString *fromJID = [layer peerAddress];
	
	NSString *toJID = [[message attributeForName:@"to"] stringValue];
	NSParameterAssert(toJID != nil);
	
	BOOL shouldForwardToReceiver = YES;
	if ([self.delegate respondsToSelector:@selector(server:shouldForwardMessage:fromNode:toNode:)]) {
		shouldForwardToReceiver = [self.delegate server:self shouldForwardMessage:message fromNode:fromJID toNode:toJID];
	}
	
	if (shouldForwardToReceiver) {
		AFXMPPConnection *remoteConnection = [self connectionForNodeName:toJID];
		[remoteConnection sendElement:message context:NULL];
		
		if (remoteConnection == nil) {
			#warning implement store and forward
		}
	}
	
	[_AFXMPPForwarder forwardElement:message from:layer to:self.delegate];
}

@end
