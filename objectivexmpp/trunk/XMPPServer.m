//
//  XMPPServer.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "XMPPServer.h"

#import "XMPPConstants.h"
#import "XMPPConnection.h"

#import <objc/message.h>
#import "AmberFoundation/AmberFoundation.h"

#warning this class should write to an error log, take a look at ASL

@interface XMPPServer ()
@property (readwrite, retain) NSDictionary *connectedNodes;
@end

@interface XMPPServer (Private)
- (XMPPConnection *)_connectionForNodeName:(NSString *)name;
- (NSString *)_nodeNameForConnection:(XMPPConnection *)connection;

- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name;
@end

@implementation XMPPServer

@dynamic delegate;

@synthesize hostnode=_hostnode;
@synthesize connectedNodes=_connectedNodes;

+ (id)server {
	return [[[self alloc] initWithEncapsulationClass:[XMPPConnection class]] autorelease];
}

- (id)initWithEncapsulationClass:(Class)clientClass {
	self = [super initWithEncapsulationClass:clientClass];
	if (self == nil) return nil;
	
	_connectedNodes = [[NSMutableDictionary alloc] init];
	_nodeSubscriptions = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_hostnode release];
	
	[_connectedNodes release];
	[_nodeSubscriptions release];
	
	[super dealloc];
}

- (void)notifySubscribersForNode:(NSString *)nodeName withPayload:(NSArray *)itemElements {
	NSXMLElement *itemsElement = [NSXMLElement elementWithName:@"items"];
	[itemsElement addAttribute:[NSXMLElement attributeWithName:@"node" stringValue:nodeName]];
	[itemsElement setChildren:itemElements];
	
	NSXMLElement *eventElement = [NSXMLElement elementWithName:@"event" URI:XMPPNamespacePubSubEventURI];	
	[eventElement addChild:itemsElement];
	
	NSXMLElement *messageElement = [NSXMLElement elementWithName:@"message"];
	[messageElement addChild:eventElement];
	
	NSSet *subscribers = [self _subscriptionsForNodeName:nodeName];
	
	for (NSString *currentJID in subscribers) {
		XMPPConnection *connection = [self.connectedNodes objectForKey:currentJID];
		if (connection == nil) continue;
		
		[messageElement setAttributes:nil];
		[messageElement addAttribute:[NSXMLElement attributeWithName:@"from" stringValue:self.hostnode]];
		[messageElement addAttribute:[NSXMLElement attributeWithName:@"to" stringValue:currentJID]];
		
		[connection sendElement:messageElement context:NULL];
	}
}

@end

@implementation XMPPServer (Delegate)

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
	(void (*)(id, SEL, id))objc_msgSendSuper(&superclass, _cmd, layer);
	if (![layer isKindOfClass:[XMPPConnection class]]) return;
	
	[_connectedNodes setObject:layer forKey:[layer peerAddress]];
}

- (void)connection:(XMPPConnection *)layer didReceiveIQ:(NSXMLElement *)iq {
	NSXMLElement *pubsubElement = [[iq elementsForName:@"pubsub"] onlyObject];
	if (pubsubElement == nil) return;
	
	NSString *nodeName = [[pubsubElement attributeForName:@"node"] stringValue];
	NSString *subscribingNode = [[pubsubElement attributeForName:@"jid"] stringValue];
	
	NSMutableSet *subscriptions = [self _subscriptionsForNodeName:nodeName];
	
	if ([[pubsubElement name] caseInsensitiveCompare:@"subscribe"] == NSOrderedSame) {
		[subscriptions addObject:subscribingNode];
	} else if ([[pubsubElement name] caseInsensitiveCompare:@"unsubscribe"] == NSOrderedSame) {
		[subscriptions removeObject:subscribingNode];
	}
	
	[layer awknowledgeElement:iq];
}

- (void)connection:(XMPPConnection *)layer didReceiveMessage:(NSXMLElement *)message {
	NSString *fromJID = [self _nodeNameForConnection:layer];
	
	NSString *toJID = [[message attributeForName:@"to"] stringValue];
	NSParameterAssert(toJID != nil);
	
	BOOL shouldForward = YES;
	if ([self.delegate respondsToSelector:@selector(server:shouldForwardMessage:fromNode:toNode:)]) {
		shouldForward = [self.delegate server:self shouldForwardMessage:message fromNode:fromJID toNode:toJID];
	}
	if (!shouldForward) return;
	
	XMPPConnection *remoteConnection = [self _connectionForNodeName:toJID];
	
	if (remoteConnection == nil) {
#warning implement store and forward
		return;
	}
	
	[remoteConnection sendElement:message context:NULL];
}

@end

@implementation XMPPServer (Private)

- (XMPPConnection *)_connectionForNodeName:(NSString *)name {
	return [[self connectedNodes] objectForKey:name];
}

- (NSString *)_nodeNameForConnection:(XMPPConnection *)connection {
	return [connection peerAddress];
}

- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name {
	NSMutableSet *subscriptions = [_nodeSubscriptions objectForKey:name];
	
	if (subscriptions == nil) {
		subscriptions = [NSMutableDictionary dictionaryWithCapacity:1];
		[_nodeSubscriptions setObject:subscriptions forKey:name];
	}
	
	return subscriptions;
}

@end
