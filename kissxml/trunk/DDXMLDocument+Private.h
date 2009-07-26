//
//  DDXMLDocument+Private.h
//  KissXML
//
//  Created by Keith Duncan on 26/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "DDXMLDocument.h"

@interface DDXMLDocument (Private)

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr;

@end
