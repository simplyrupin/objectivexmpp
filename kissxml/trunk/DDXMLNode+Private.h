//
//  DDXMLNode+Private.h
//  KissXML
//
//  Created by Keith Duncan on 26/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "DDXMLNode.h"

@interface DDXMLNode (Private)

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr;
- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr;

+ (id)nodeWithPrimitive:(xmlKindPtr)nodePtr nsParent:(xmlNodePtr)parentPtr;
- (id)initWithCheckedPrimitive:(xmlKindPtr)nodePtr nsParent:(xmlNodePtr)parentPtr;
- (id)initWithUncheckedPrimitive:(xmlKindPtr)nodePtr nsParent:(xmlNodePtr)parentPtr;

+ (BOOL)isXmlAttrPtr:(xmlKindPtr)kindPtr;
- (BOOL)isXmlAttrPtr;

+ (BOOL)isXmlNodePtr:(xmlKindPtr)kindPtr;
- (BOOL)isXmlNodePtr;

+ (BOOL)isXmlDocPtr:(xmlKindPtr)kindPtr;
- (BOOL)isXmlDocPtr;

+ (BOOL)isXmlDtdPtr:(xmlKindPtr)kindPtr;
- (BOOL)isXmlDtdPtr;

+ (BOOL)isXmlNsPtr:(xmlKindPtr)kindPtr;
- (BOOL)isXmlNsPtr;

- (BOOL)hasParent;

+ (void)recursiveStripDocPointersFromNode:(xmlNodePtr)node;

+ (void)detachAttribute:(xmlAttrPtr)attr fromNode:(xmlNodePtr)node;
+ (void)removeAttribute:(xmlAttrPtr)attr fromNode:(xmlNodePtr)node;
+ (void)removeAllAttributesFromNode:(xmlNodePtr)node;

+ (void)detachNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeAllNamespacesFromNode:(xmlNodePtr)node;

+ (void)detachChild:(xmlNodePtr)child fromNode:(xmlNodePtr)node;
+ (void)removeChild:(xmlNodePtr)child fromNode:(xmlNodePtr)node;
+ (void)removeAllChildrenFromNode:(xmlNodePtr)node;

+ (void)removeAllChildrenFromDoc:(xmlDocPtr)doc;

- (void)nodeRetain;
- (void)nodeRelease;

+ (NSError *)lastError;

@end
