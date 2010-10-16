//
//  AFXMPPServer+AFPubSubAdditions.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 16/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import "AFXMPPServer+AFPubSubAdditions.h"

#import "objc/runtime.h"
#import "AmberFoundation/AmberFoundation.h"

#import "AFXMPPConnection.h"
#import "AFXMPPConstants.h"
#import "AFXMPPMessage.h"

@implementation AFXMPPServer (AFPubSubAdditions)

NSSTRING_CONTEXT(AFXMPPServerPubSubAdditionsSubscribersAssociationContext);

- (NSMutableDictionary *)_mutableNotificationSubscribers {
	return objc_getAssociatedObject(self, &AFXMPPServerPubSubAdditionsSubscribersAssociationContext);
}

- (NSDictionary *)notificationSubscribers {
	return [[[self _mutableNotificationSubscribers] copy] autorelease];
}

- (AFXMPPConnection *)_connectionForNodeName:(NSString *)name {
	return [[self connectedNodes] objectForKey:name];
}

- (NSString *)_nodeNameForConnection:(AFXMPPConnection *)connection {
	return [connection peerAddress];
}

- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name {
	NSMutableDictionary *notificationSubscribers = [self _mutableNotificationSubscribers];
	
	NSMutableSet *subscriptions = [notificationSubscribers objectForKey:name];
	
	if (subscriptions == nil) {
		subscriptions = [NSMutableDictionary dictionary];
		[notificationSubscribers setObject:subscriptions forKey:name];
	}
	
	return subscriptions;
}

- (void)notifySubscribersForNode:(NSString *)nodeName withPayload:(NSArray *)itemElements {
	NSXMLElement *itemsElement = [NSXMLElement elementWithName:@"items"];
	[itemsElement addAttribute:[NSXMLElement attributeWithName:@"node" stringValue:nodeName]];
	[itemsElement setChildren:itemElements];
	
	NSXMLElement *eventElement = [NSXMLElement elementWithName:@"event" URI:AFXMPPNamespacePubSubEventURI];
	[eventElement addChild:itemsElement];
	
	NSXMLElement *messageElement = [NSXMLElement elementWithName:AFXMPPStanzaMessageElementName];
	[messageElement addChild:eventElement];
	
	NSSet *subscribers = [self _subscriptionsForNodeName:nodeName];
	
	for (NSString *currentJID in subscribers) {
		AFXMPPConnection *connection = [[self connectedNodes] objectForKey:currentJID];
		if (connection == nil) continue;
		
		[messageElement setAttributes:nil];
		[messageElement addAttribute:[NSXMLElement attributeWithName:@"from" stringValue:[self hostnode]]];
		[messageElement addAttribute:[NSXMLElement attributeWithName:@"to" stringValue:currentJID]];
		
		[connection sendElement:messageElement context:NULL];
	}
}

@end
