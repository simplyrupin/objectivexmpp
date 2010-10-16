//
//  XMPPMessage.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 04/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\file
	Exposes constants for the construction of XMPP stanza elements.
 */

/*
	Stanza Names
 */

extern NSString *const AFXMPPStanzaMessageElementName;
extern NSString *const AFXMPPStanzaIQElementName;
extern NSString *const AFXMPPStanzaPresenceElementName;

/*!
	\brief
	This element is transmitted after the opening of the XML stream to indicate which features the server supports.
 */
extern NSString *const AFXMPPStreamFeaturesLocalElementName;

/*!
	\brief
	A <message/> element suitable for serialising.
 */
extern NSXMLElement *AFXMPPMessageWithBody(NSString *bodyValue);

/*!
	\brief
	Determines if a <message/> is mid-composition.
 */
extern BOOL AFXMPPMessageIsComposing(NSXMLElement *element);
