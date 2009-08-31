//
//  NSXMLNode+Additions.h
//  ObjectiveXMPP
//
//  Created by Keith Duncan on 31/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSXMLNode (Additions)

- (NSArray *)nodesForXPath:(NSString *)xpath namespaces:(NSDictionary *)prefixMappings error:(NSError **)error;

@end
