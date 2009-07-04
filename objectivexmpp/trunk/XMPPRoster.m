//
//  XMPPRoster.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 05/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "XMPPRoster.h"

#import "XMPPChatService.h"
#import "XMPPConstants.h"

#import "AmberFoundation/AmberFoundation.h"

NSString *const kXMPPRosterBonjourDomain = @"local.";

@interface XMPPRoster ()
@property (readwrite, retain) NSNetServiceBrowser *browser;
@end

@implementation XMPPRoster

@synthesize browser;
@synthesize bonjourServices;

+ (XMPPRoster *)sharedRoster {
	static XMPPRoster *sharedRoster = nil;
	if (sharedRoster == nil) sharedRoster = [[XMPPRoster alloc] init];
	return sharedRoster;
}

- (id)init {
	self = [super init];
	
	browser = [[NSNetServiceBrowser alloc] init];
	[browser setDelegate:(id)self];
	
	bonjourServices = [[AFKeyIndexedSet alloc] initWithKeyPath:@"name"];
	
	return self;
}

- (void)dealloc {
	[browser release];
	
	[bonjourServices release];
	
	[super dealloc];
}

- (void)searchForBonjourServices {
	[self.browser searchForServicesOfType:XMPPServiceType inDomain:kXMPPRosterBonjourDomain];
}

- (void)addBonjourServicesObject:(XMPPChatService *)object {
	[bonjourServices addObject:object];
}

- (void)removeBonjourServicesObject:(XMPPChatService *)object {
	[bonjourServices removeObject:object];
}

@end

@implementation XMPPRoster (Delegate)

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing {	
	XMPPChatService *service = [[XMPPChatService alloc] initWithNetService:netService];
	[self addBonjourServicesObject:service];
	[service release];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	[self removeBonjourServicesObject:(id)netService];
}

@end
