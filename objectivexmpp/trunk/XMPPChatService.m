//
//  XMPPService.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "XMPPChatService.h"

#import "AmberFoundation/AmberFoundation.h"

#import "CoreNetworking/AFServiceDiscoveryRunLoopSource.h"

NSString *const XMPPServicePresenceStatusKey = @"status";
NSString *const XMPPServicePresenceStatusAvailableValue = @"avail";
NSString *const XMPPServicePresenceStatusBusyValue = @"dnd";
NSString *const XMPPServicePresenceStatusIdleValue = @"away";

NSString *const XMPPServicePresenceMessageKey = @"msg";
NSString *const XMPPServicePresenceAvatarHashKey = @"phsh";

NSString *const XMPPServicePresenceFirstNameKey = @"1st";
NSString *const XMPPServicePresenceLastNameKey = @"last";

@interface XMPPChatService ()
@property (readwrite, retain) NSData *avatarData;
@end

@interface XMPPChatService (Private)
- (void)_setupAvatarQuery;
- (void)_teardownAvatarQuery;
@end

@implementation XMPPChatService

@synthesize avatarData=_avatarData;

- (void)dealloc {	
	[self _teardownAvatarQuery];
	[_avatarData release];
	
	[super dealloc];
}

- (NSString *)identifier {
	return self.name;
}

- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence {	
	NSString *newHash = [newPresence valueForKey:XMPPServicePresenceAvatarHashKey];
	
	if (![newHash isEqual:[self.presence valueForKey:XMPPServicePresenceAvatarHashKey]]) {
		if (newHash == nil || [newHash isEmpty]) {
			self.avatarData = nil;
		} else {
			[self _setupAvatarQuery];
		}
	}
	
	[super updatePresenceWithValuesForKeys:newPresence];
}

@end

@implementation XMPPChatService (Private)

static void ImageQueryReply(DNSServiceRef serviceRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *fullname, uint16_t rrtype, uint16_t rrclass, uint16_t rdlen, const void *rdata, uint32_t ttl, void *context) {
	XMPPChatService *self = context;
	
	if (errorCode != kDNSServiceErr_NoError) {
		NSLog(@"%s, errorCode %d, deallocating query.", __PRETTY_FUNCTION__, errorCode, nil);
		[self _teardownAvatarQuery];
		return;
	}
	
	if (rdata == NULL)
		self.avatarData = nil;
	else
		self.avatarData = [NSData dataWithBytes:rdata length:rdlen];
	
	[self _teardownAvatarQuery]; // Note: in accordance with XEP-0174 the avatar query should be single shot, a TXT record update will inform client of any change
}

- (void)_setupAvatarQuery {
	[self _teardownAvatarQuery];
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceQueryRecord(&avatarQuery, 0, kDNSServiceInterfaceIndexAny, [[self fullName] UTF8String], kDNSServiceType_NULL, kDNSServiceClass_IN, ImageQueryReply, self);
	
	if (error == kDNSServiceErr_NoError) {
		avatarQuerySource = [[AFServiceDiscoveryRunLoopSource alloc] initWithService:avatarQuery];
		[avatarQuerySource scheduleInRunLoop:CFRunLoopGetMain() forMode:kCFRunLoopCommonModes];
	}
}

- (void)_teardownAvatarQuery {
	[avatarQuerySource invalidate];
	[avatarQuerySource release];
	avatarQuerySource = nil;
	
	DNSServiceRefDeallocate(avatarQuery);
	avatarQuery = NULL;
}

@end
