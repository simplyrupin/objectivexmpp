//
//  AFXMPPServer+AFPubSubAdditions.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 16/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import "AFXMPPPubSubModule.h"

#import "objc/runtime.h"
#import "AmberFoundation/AmberFoundation.h"

#import "AFXMPPConnection.h"
#import "AFXMPPConstants.h"
#import "AFXMPPMessage.h"

@interface AFXMPPServer (AFXMPPPubSubAdditionsPrivate)
- (NSMutableDictionary *)_mutableNotificationSubscribers;
- (NSDictionary *)notificationSubscribers;
- (NSMutableSet *)_subscriptionsForNodeName:(NSString *)name;
@end

@implementation AFXMPPServer (AFPubSubAdditions)

- (BOOL)server:(AFXMPPServer *)server shouldHandleElement:(NSXMLElement *)element fromConnection:(AFXMPPConnection *)connection {
	NSXMLElement *pubsubElement = [[iq elementsForName:@"pubsub"] onlyObject];
	if (pubsubElement == nil) return NO;
	
	NSString *nodeName = [[pubsubElement attributeForName:@"node"] stringValue];
	NSString *subscribingNode = [[pubsubElement attributeForName:@"jid"] stringValue];
	
	NSMutableSet *subscriptions = [self _subscriptionsForNodeName:nodeName];
	
	if ([[pubsubElement name] caseInsensitiveCompare:@"subscribe"] == NSOrderedSame) {
		[subscriptions addObject:subscribingNode];
	} else if ([[pubsubElement name] caseInsensitiveCompare:@"unsubscribe"] == NSOrderedSame) {
		[subscriptions removeObject:subscribingNode];
	}
	
	[connection awknowledgeIQElement:element];
	
	return YES;
}

@end

@implementation AFXMPPServer (AFXMPPPubSubAdditionsPrivate)

NSSTRING_CONTEXT(AFXMPPServerPubSubAdditionsSubscribersAssociationContext);

- (NSMutableDictionary *)_mutableNotificationSubscribers {
	return objc_getAssociatedObject(self, &AFXMPPServerPubSubAdditionsSubscribersAssociationContext);
}

- (NSDictionary *)notificationSubscribers {
	return [[[self _mutableNotificationSubscribers] copy] autorelease];
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

@end

@implementation AFXMPPServer (AFXMPPPubSubAdditions)

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
