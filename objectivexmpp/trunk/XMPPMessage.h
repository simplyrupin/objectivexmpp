//
//  XMPPMessage.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@header
	Exposes constants for the construction of XMPP stanza elements.
 */

/*!
	@brief
	This element is transmitted after the opening of the XML stream to indicate which features the server supports.
 */
extern NSString *const XMPPStreamFeaturesLocalElementName;

/*
	Stanza Names
 */

extern NSString *const XMPPStreamMessageElementName;
extern NSString *const XMPPStreamIQElementName;
extern NSString *const XMPPStreamPresenceElementName;

/*!
	@brief
	Use this function to determine if the message represents a message mid-compose.
 */
extern BOOL XMPPMessageIsComposing(NSXMLElement *element);
