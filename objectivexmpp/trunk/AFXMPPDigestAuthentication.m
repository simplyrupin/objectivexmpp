//
//  XMPPDigestAuthentication.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 31/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFXMPPDigestAuthentication.h"

#import "AmberFoundation/AmberFoundation.h"

NSString *const AFXMPPAuthenticationSchemePLAIN = @"PLAIN";
NSString *const AFXMPPAuthenticationSchemeDigestMD5 = @"DIGEST-MD5";

@implementation AFXMPPDigestAuthentication

@synthesize rspauth, realm, digestURI, username, password;

- (id)initWithChallenge:(NSXMLElement *)challenge {
	self = [self init];
	if (self == nil) return nil;
	
	NSData *decodedData = [NSData dataWithBase64String:[challenge stringValue]];
	NSString *authStr = [[[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding] autorelease];
	
	// Extract all the key=value pairs, and put them in a dictionary for easy lookup
	NSMutableDictionary *auth = [NSMutableDictionary dictionary];
	
	NSArray *components = [authStr componentsSeparatedByString:@","];
	
	for (NSUInteger i = 0; i < [components count]; i++) {
		NSString *component = [components objectAtIndex:i];
		
		NSRange separator = [component rangeOfString:@"="];
		if (separator.location == NSNotFound) continue;
		
		NSString *key = [component substringToIndex:separator.location];
		NSString *value = [component substringFromIndex:separator.location + 1];
		
		if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2) {
			// Strip quotes from value
			value = [value substringWithRange:NSMakeRange(1, ([value length] - 2))];
		}
		
		[auth setObject:value forKey:key];
	}
	
	// Extract and retain the elements we need
	rspauth = [[auth objectForKey:@"rspauth"] copy];
	realm = [[auth objectForKey:@"realm"] copy];
	nonce = [[auth objectForKey:@"nonce"] copy];
	qop = [[auth objectForKey:@"qop"] copy];
	
	// Generate cnonce
	CFUUIDRef uuid = (CFUUIDRef)[NSMakeCollectable(CFUUIDCreate(NULL)) autorelease];
	cnonce = (NSString *)CFMakeCollectable(CFUUIDCreateString(NULL, uuid));
	
	return self;
}

- (void)dealloc {
	[rspauth release];
	[realm release];
	[digestURI release];
	[nonce release];
	[qop release];
	[username release];
	[password release];
	[cnonce release];
	[nc release];
	
	[super dealloc];
}

- (NSString *)response {
	NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", username, realm, password];
	NSString *HA2str = [NSString stringWithFormat:@"AUTHENTICATE:%@", digestURI];
	
	NSData *HA1dataA = [[HA1str dataUsingEncoding:NSUTF8StringEncoding] MD5Hash];
	NSData *HA1dataB = [[NSString stringWithFormat:@":%@:%@", nonce, cnonce] dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableData *HA1data = [NSMutableData dataWithCapacity:([HA1dataA length] + [HA1dataB length])];
	[HA1data appendData:HA1dataA];
	[HA1data appendData:HA1dataB];
	
	NSString *HA1 = [[HA1data MD5Hash] base16String];
	NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] MD5Hash] base16String];
	
	NSString *responseStr = [NSString stringWithFormat:@"%@:%@:00000001:%@:auth:%@", HA1, nonce, cnonce, HA2];
	NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] MD5Hash] base16String];
	
	return response;
}

- (NSString *)fullResponse {
	NSMutableString *buffer = [NSMutableString stringWithCapacity:100];
	[buffer appendFormat:@"username=\"%@\",", username];
	[buffer appendFormat:@"realm=\"%@\",", realm];
	[buffer appendFormat:@"nonce=\"%@\",", nonce];
	[buffer appendFormat:@"cnonce=\"%@\",", cnonce];
	[buffer appendFormat:@"nc=00000001,"];
	[buffer appendFormat:@"qop=auth,"];
	[buffer appendFormat:@"digest-uri=\"%@\",", digestURI];
	[buffer appendFormat:@"response=%@,", [self response]];
	[buffer appendFormat:@"charset=utf-8"];
	return [[buffer dataUsingEncoding:NSUTF8StringEncoding] base64String];
}

@end
