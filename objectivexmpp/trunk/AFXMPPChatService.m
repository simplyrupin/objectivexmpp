//
//  XMPPService.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 30/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFXMPPChatService.h"

#import "AmberFoundation/AmberFoundation.h"
#import "CoreNetworking/CoreNetworking.h"

NSString *const XMPPServicePresenceStatusKey = @"status";
NSString *const XMPPServicePresenceStatusAvailableValue = @"avail";
NSString *const XMPPServicePresenceStatusBusyValue = @"dnd";
NSString *const XMPPServicePresenceStatusIdleValue = @"away";

NSString *const XMPPServicePresenceMessageKey = @"msg";
NSString *const XMPPServicePresenceAvatarHashKey = @"phsh";

NSString *const XMPPServicePresenceFirstNameKey = @"1st";
NSString *const XMPPServicePresenceLastNameKey = @"last";

@interface AFXMPPChatService ()
@property (readwrite, retain) NSData *avatarData;
@end

@interface AFXMPPChatService (Private)
- (void)_setupAvatarQuery;
- (void)_teardownAvatarQuery;
@end

@implementation AFXMPPChatService

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

@implementation AFXMPPChatService (Private)

static void ImageQueryReply(DNSServiceRef serviceRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *fullname, uint16_t rrtype, uint16_t rrclass, uint16_t rdlen, const void *rdata, uint32_t ttl, void *context) {
	AFXMPPChatService *self = context;
	
	if (errorCode != kDNSServiceErr_NoError) {
		NSLog(@"%s, errorCode %d, deallocating query.", __PRETTY_FUNCTION__, errorCode, nil);
		[self _teardownAvatarQuery];
		return;
	}
	
	self.avatarData = (rdata == NULL) ? nil : [NSData dataWithBytes:rdata length:rdlen];
	
	// Note: as per XEP-0174 the avatar query should be single shot, a TXT record update will inform client of any change
	[self _teardownAvatarQuery];
}

- (void)_setupAvatarQuery {
	[self _teardownAvatarQuery];
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	
	error = DNSServiceQueryRecord(&avatarQuery, 0, kDNSServiceInterfaceIndexAny, [[self fullName] UTF8String], kDNSServiceType_NULL, kDNSServiceClass_IN, ImageQueryReply, self);
	if (error != kDNSServiceErr_NoError) return;
	
	avatarQuerySource = [[AFServiceDiscoveryRunLoopSource alloc] initWithService:avatarQuery];
	[avatarQuerySource scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)_teardownAvatarQuery {
	[avatarQuerySource invalidate];
	[avatarQuerySource release];
	avatarQuerySource = nil;
	
	DNSServiceRefDeallocate(avatarQuery);
	avatarQuery = NULL;
}

@end
