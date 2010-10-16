//
//  XMPPDigestAuthentication.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 31/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSXMLElement;

extern NSString *const AFXMPPAuthenticationSchemePLAIN;
extern NSString *const AFXMPPAuthenticationSchemeDigestMD5;

@interface AFXMPPDigestAuthentication : NSObject {
 @private
	NSString *rspauth;
	NSString *realm;
	NSString *digestURI;
	NSString *nonce;
	NSString *qop;
	NSString *username;
	NSString *password;
	NSString *cnonce;
	NSString *nc;
}

/*!
	@brief
	Designated Initialiser.
 */
- (id)initWithChallenge:(NSXMLElement *)challenge;

@property (readonly) NSString *rspauth;

@property (copy) NSString *realm;

@property (copy) NSString *digestURI;

@property (copy) NSString *username;
@property (copy) NSString *password;

/*!
	@brief
	
 */
- (NSString *)response;

/*!
	@brief
	
 */
- (NSString *)fullResponse;

@end
