//
//  AFXMPPServerModule.m
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 16/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import "AFXMPPServerModule.h"

@implementation AFXMPPServerModule

- (BOOL)server:(AFXMPPServer *)server shouldProcessElement:(NSXMLElement *)element fromConnection:(AFXMPPConnection *)connection {
	return NO;
}

@end
