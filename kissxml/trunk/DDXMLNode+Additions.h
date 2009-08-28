//
//  DDXMLNode+Additions.h
//  KissXML
//
//  Created by Keith Duncan on 25/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KissXML/DDXMLNode.h"

@interface DDXMLNode (Additions)

- (NSArray *)nodesForXPath:(NSString *)xpath namespaces:(NSDictionary *)prefixMapping error:(NSError **)error;

@end
