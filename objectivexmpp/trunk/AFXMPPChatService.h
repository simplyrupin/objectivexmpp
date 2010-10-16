//
//  XMPPService.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetService.h"

#import <dns_sd.h>

@class AFServiceDiscoveryRunLoopSource;

/*
	Local-Link TXT Record Keys and Values
 */

extern NSString *const XMPPServicePresenceStatusKey;
extern NSString *const XMPPServicePresenceStatusAvailableValue;
extern NSString *const XMPPServicePresenceStatusBusyValue;
extern NSString *const XMPPServicePresenceStatusIdleValue;

extern NSString *const XMPPServicePresenceMessageKey;
extern NSString *const XMPPServicePresenceAvatarHashKey;

extern NSString *const XMPPServicePresenceFirstNameKey;
extern NSString *const XMPPServicePresenceLastNameKey;

/*!
	\brief
	This service subclass encapsualtes an advertised _presence._tcp service and the behaviours accociated.
 */
@interface AFXMPPChatService : AFNetService {
 @private
	NSData *_avatarData;
	
	DNSServiceRef avatarQuery;
	AFServiceDiscoveryRunLoopSource *avatarQuerySource;
}

/*!
	\brief
	This is the JID of the endpoint, identifier just sounds nicer than JID.
 */
@property (readonly) NSString *identifier;

/*!
	\brief
	This property returns the image data rather than the image itself so that it is presentation-layer portable.
	
	\details
	This is KVO compliant, when the service changes it's avatar, this property will auto-update.
 */
@property (readonly, retain) NSData *avatarData;

@end
