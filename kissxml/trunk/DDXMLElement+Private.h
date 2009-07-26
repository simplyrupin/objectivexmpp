//
//  DDXMLElement+Private.h
//  KissXML
//
//  Created by Keith Duncan on 26/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "DDXMLElement.h"

@interface DDXMLElement (Private)

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr;

- (NSArray *)elementsWithName:(NSString *)name uri:(NSString *)URI;

+ (DDXMLNode *)resolveNamespaceForPrefix:(NSString *)prefix atNode:(xmlNodePtr)nodePtr;
+ (NSString *)resolvePrefixForURI:(NSString *)uri atNode:(xmlNodePtr)nodePtr;

@end
