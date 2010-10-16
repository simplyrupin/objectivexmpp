//
//  XMPPRoster.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "AFXMPPRoster.h"

#import "AFXMPPChatService.h"
#import "XMPPConstants.h"

#import "AmberFoundation/AmberFoundation.h"
#import "CoreNetworking/CoreNetworking.h"

NSString *const kXMPPRosterBonjourDomain = @"local.";

@interface AFXMPPRoster ()
@property (readwrite, retain) NSNetServiceBrowser *browser;
@end

@implementation AFXMPPRoster

@synthesize browser=_browser;
@synthesize bonjourServices=_bonjourServices;

+ (AFXMPPRoster *)sharedRoster {
	static AFXMPPRoster *sharedRoster = nil;
	if (sharedRoster == nil) sharedRoster = [[AFXMPPRoster alloc] init];
	return sharedRoster;
}

- (id)init {
	self = [super init];
	
	_browser = [[NSNetServiceBrowser alloc] init];
	[_browser setDelegate:(id)self];
	
	_bonjourServices = [[AFKeyIndexedSet alloc] initWithKeyPath:@"name"];
	
	return self;
}

- (void)dealloc {
	[_browser release];
	
	[_bonjourServices release];
	
	[super dealloc];
}

- (void)searchForBonjourServices {
	[self.browser searchForServicesOfType:XMPPServiceDiscoveryType inDomain:kXMPPRosterBonjourDomain];
}

- (void)addBonjourServicesObject:(AFXMPPChatService *)object {
	[bonjourServices addObject:object];
}

- (void)removeBonjourServicesObject:(AFXMPPChatService *)object {
	[bonjourServices removeObject:object];
}

@end

@implementation AFXMPPRoster (Delegate)

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing {	
	AFXMPPChatService *service = [[AFXMPPChatService alloc] initWithNetService:netService];
	[self addBonjourServicesObject:service];
	[service release];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	[self removeBonjourServicesObject:(id)netService];
}

@end
