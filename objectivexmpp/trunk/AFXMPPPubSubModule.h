//
//  AFXMPPServer+AFPubSubAdditions.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 16/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AFXMPPServerModule.h"
#import "AFXMPPServer.h"

/*
	\file
	PubSub is documented in XEP-0060 
 */

@interface AFXMPPPubSubModule : AFXMPPServerModule

/*!
	\brief
	
 */
@property (readonly) NSDictionary *notificationSubscribers;

@end

@interface AFXMPPServer (AFXMPPPubSubAdditions)

/*!
	\brief
	
 */
- (void)notifySubscribersForNode:(NSString *)nodeName withPayload:(NSArray *)itemElements;

@end
