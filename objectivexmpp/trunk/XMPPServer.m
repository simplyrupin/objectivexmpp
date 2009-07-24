//
//  XMPPServer.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "XMPPServer.h"

#import "AmberFoundation/AmberFoundation.h"
#import "TouchXML/TouchXML.h"

#import "XMPPConnection.h"

#warning this class should write to an error log, take a look at ASL

@interface XMPPServer ()
@property (readwrite, retain) NSDictionary *connectedNodes;
@end

@interface XMPPServer (Private)
- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name;
@end

@implementation XMPPServer

@dynamic delegate;

@synthesize hostnode=_hostnode;
@synthesize connectedNodes=_connectedNodes;

+ (id)server {
	return [[[self alloc] initWithLowerLayer:[AFNetworkServer server] encapsulationClass:[XMPPConnection class]] autorelease];
}

- (id)initWithLowerLayer:(AFNetworkServer *)lowerLayer encapsulationClass:(Class)clientClass {
	self = [super initWithLowerLayer:lowerLayer encapsulationClass:clientClass];
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
	CXMLElement *itemsElement = [CXMLElement elementWithName:@"items"];
	[itemsElement addAttributeWithName:@"node" stringValue:nodeName];
	[itemsElement setChildren:itemElements];
	
	CXMLElement *eventElement = [CXMLElement elementWithName:@"event" xmlns:@"http://jabber.org/protocol/pubsub#event"];
	[eventElement addChild:itemsElement];
	
	CXMLElement *messageElement = [CXMLElement elementWithName:@"message"];
	[messageElement addChild:eventElement];
	
	NSSet *subscribers = [self _subscriptionsForNodeName:nodeName];
	
	for (NSString *currentJID in subscribers) {
		XMPPConnection *connection = [self.connectedNodes objectForKey:currentJID];
		if (connection == nil) continue;
		
		[messageElement setAttributes:nil];
		[messageElement addAttributeWithName:@"from" stringValue:self.hostnode];
		[messageElement addAttributeWithName:@"to" stringValue:currentJID];
		
		[connection sendElement:messageElement];
	}
}

@end

@implementation XMPPServer (Delegate)

- (void)connection:(XMPPConnection *)layer didReceiveIQ:(CXMLElement *)iq {
	NSMutableArray *pubsubElements = [[[iq children] mutableCopy] autorelease];
	for (CXMLElement *currentElement in [[pubsubElements copy] autorelease])
		if (![[currentElement name] isEqualToString:@"pubsub"]) continue;
	
	if ([pubsubElements count] != 1) return;
	
	CXMLElement *pubsubChildElement = [pubsubElements objectAtIndex:0];
	if (pubsubChildElement == nil) return;
	
	NSString *nodeName = [[pubsubChildElement attributeForName:@"node"] stringValue];
	NSString *subscribingNode = [[pubsubChildElement attributeForName:@"jid"] stringValue];
	
	NSMutableSet *subscriptions = [self _subscriptionsForNodeName:nodeName];
	
	if ([[[pubsubChildElement name] lowercaseString] isEqualToString:@"subscribe"]) {
		[subscriptions addObject:subscribingNode];
	} else if ([[[pubsubChildElement name] lowercaseString] isEqualToString:@"unsubscribe"]) {
		[subscriptions removeObject:subscribingNode];
	}
	
	[layer awknowledgeElement:iq];
}

- (void)connection:(XMPPConnection *)layer didReceiveMessage:(CXMLElement *)message {
	NSString *fromJID = nil;
	CXMLNode *fromAttribute = [message attributeForName:@"from"];
	
	if (fromAttribute != nil) {
		fromJID = [fromAttribute stringValue];
	} else {
		NSArray *JIDCollection = (id)[self.connectedNodes allKeysForObject:layer];
		NSAssert([(id)JIDCollection count] == 1, ([NSString stringWithFormat:@"Connection %p may only register one JID, %d found", layer, [(id)fromJID count], nil]));
		fromJID = [(id)JIDCollection objectAtIndex:0];
	}
	
	NSAssert(fromJID != nil, ([NSString stringWithFormat:@"%s, couldn't determine the sender of message %p" /* The error string can state 'message', because other types aren't forwarded */ , __PRETTY_FUNCTION__, message, nil]));
	
	NSString *toJID = [[message attributeForName:@"to"] stringValue];
	NSAssert(toJID != nil, ([NSString stringWithFormat:@"%s, couldn't determine the recipient of message %p" /* The error string can state 'message', because other types aren't forwarded */ , __PRETTY_FUNCTION__, message, nil]));
	
	BOOL shouldForward = YES;
	if ([self.delegate respondsToSelector:@selector(server:shouldForwardMessage:fromNode:toNode:)]) {
		shouldForward = [self.delegate server:self shouldForwardMessage:message fromNode:fromJID toNode:toJID];
	} if (!shouldForward) return;
	
	XMPPConnection *remoteConnection = (id)[self.clients layerWithValue:toJID forKey:@"peer"];
	NSParameterAssert(remoteConnection != nil);
	
	if (fromAttribute == nil) [message addAttributeWithName:@"from" stringValue:fromJID];
	
	[remoteConnection sendElement:message];
}

@end

@implementation XMPPServer (Private)

- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name {
	NSMutableSet *subscriptions = [_nodeSubscriptions objectForKey:name];
	
	if (subscriptions == nil) {
		subscriptions = [NSMutableDictionary dictionaryWithCapacity:1];
		[_nodeSubscriptions setObject:subscriptions forKey:name];
	}
	
	return subscriptions;
}

@end
