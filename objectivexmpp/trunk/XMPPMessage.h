//
//  XMPPMessage.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
	Stanza Names
 */

extern NSString *const XMPPStanzaMessageElementName;
extern NSString *const XMPPStanzaIQElementName;
extern NSString *const XMPPStanzaPresenceElementName;

/*!
	@header
	Exposes constants for the construction of XMPP stanza elements.
 */

/*!
	\brief
	This element is transmitted after the opening of the XML stream to indicate which features the server supports.
 */
extern NSString *const XMPPStreamFeaturesLocalElementName;

/*!
	\brief
	This function takes either an NSXMLElement representing an HTML body, or a string.
 
	\return
	A <message/> element suitable for serialising.
 */
extern NSXMLElement *XMPPMessageWithBody(NSString *bodyValue);

/*!
	\brief
	Use this function to determine if the message represents a message mid-compose.
 */
extern BOOL XMPPMessageIsComposing(NSXMLElement *element);
