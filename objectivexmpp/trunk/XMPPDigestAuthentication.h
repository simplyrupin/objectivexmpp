//
//  XMPPDigestAuthentication.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 31/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSXMLElement;

extern NSString *const XMPPAuthenticationSchemePLAIN;
extern NSString *const XMPPAuthenticationSchemeDigestMD5;

@interface XMPPDigestAuthentication : NSObject
{
	NSString *rspauth;
	NSString *realm;
	NSString *nonce;
	NSString *qop;
	NSString *username;
	NSString *password;
	NSString *cnonce;
	NSString *nc;
	NSString *digestURI;
}

- (id)initWithChallenge:(NSXMLElement *)challenge;

- (NSString *)rspauth;

- (NSString *)realm;
- (void)setRealm:(NSString *)realm;

- (void)setDigestURI:(NSString *)digestURI;

- (void)setUsername:(NSString *)username password:(NSString *)password;

- (NSString *)response;
- (NSString *)base64EncodedFullResponse;

@end
