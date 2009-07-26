//
//  CXMLNode.m
//  TouchCode
//
//  Created by Jonathan Wight on 03/07/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "CXMLNode.h"

#import "CXMLNode_PrivateExtensions.h"
#import "CXMLDocument.h"
#import "CXMLElement.h"

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

@implementation CXMLNode

static void CXMLErrorHandler(void *userData, xmlErrorPtr error)
{
	// This method is called by libxml when an error occurs.
	// We register for this error in the initialize method below.
	
	// Extract error message and store in the current thread's dictionary.
	// This ensure's thread safey, and easy access for all other DDXML classes.
	
	static NSString *const CXMLLastErrorKey = @"CXMLError";
	
	if (error == NULL)
	{
		[[[NSThread currentThread] threadDictionary] removeObjectForKey:CXMLLastErrorKey];
	}
	else
	{
		NSValue *errorValue = [NSValue valueWithBytes:error objCType:@encode(xmlError)];
		[[[NSThread currentThread] threadDictionary] setObject:errorValue forKey:CXMLLastErrorKey];
	}
}

+ (void)initialize
{
	if (self != [CXMLNode class]) return;
	
	// Redirect error output to our own function (don't clog up the console)
	initGenericErrorDefaultFunc(NULL);
	xmlSetStructuredErrorFunc(NULL, CXMLErrorHandler);
	
	// Tell libxml not to keep ignorable whitespace (such as node indentation, formatting, etc).
	// NSXML ignores such whitespace.
	// This also has the added benefit of taking up less RAM when parsing formatted XML documents.
	xmlKeepBlanksDefault(0);
}

- (void)dealloc
{
	// Check if genericPtr is NULL
	// This may be the case if, eg, DDXMLElement calls [self release] from it's init method
	
	if (_node != NULL)
	{
		[self _nodeRelease];
	}
	
	[super dealloc];
}

static BOOL _CXMLKindIsNode(CXMLNodeKind type) {	
	switch (type) {
		case XML_ELEMENT_NODE:
		case XML_PI_NODE: 
		case XML_COMMENT_NODE: 
		case XML_TEXT_NODE: 
		case XML_CDATA_SECTION_NODE:
			return YES;
	}
	
	return NO;
}

- (id)copyWithZone:(NSZone *)zone
{	
	if ([self kind] == CXMLDocumentKind) {
		xmlDocPtr copyDocPtr = xmlCopyDoc((xmlDocPtr)_node, 1);
		return [[CXMLDocument alloc] initWithLibXMLNode:(xmlNodePtr)copyDocPtr];
	}
	
	if (_CXMLKindIsNode([self kind])) {
		xmlNodePtr copyNodePtr = xmlCopyNode(_node, 1);
		return [[[self class] alloc] initWithLibXMLNode:copyNodePtr];
	}
	
	if ([self kind] == CXMLAttributeKind) {
		xmlAttrPtr copyAttrPtr = xmlCopyProp(NULL, (xmlAttrPtr)_node);
		return [[[self class] alloc] initWithLibXMLNode:(xmlNodePtr)copyAttrPtr];
	}
	
	if ([self kind] == CXMLNamespaceKind) {
		xmlNsPtr copyNsPtr = xmlCopyNamespace((xmlNsPtr)_node);
		return [[[self class] alloc] initWithLibXMLNode:(xmlNodePtr)copyNsPtr];
	}
	
	if ([self kind] == CXMLDTDKind) {
		xmlDtdPtr copyDtdPtr = xmlCopyDtd((xmlDtdPtr)_node);
		return [[[self class] alloc] initWithLibXMLNode:(xmlNodePtr)copyDtdPtr];
	}
	
	return nil;
}

#pragma mark -

- (CXMLNodeKind)kind
{
	if (_node == NULL) return CXMLInvalidKind;
	return(_node->type);
}

- (NSString *)name
{
	if ([self kind] == CXMLNamespaceKind)
	{
		xmlNsPtr ns = (xmlNsPtr)_node;
		
		if (ns->prefix != NULL)
			return [NSString stringWithUTF8String:((const char *)ns->prefix)];
		else
			return @"";
	}
	
	const char *name = (const char *)_node->name;
	return (name != NULL) ? [NSString stringWithUTF8String:name] : nil;
}

- (void)setName:(NSString *)name
{
	if ([self kind] == CXMLNamespaceKind)
	{
		xmlNsPtr ns = (xmlNsPtr)_node;
		
		xmlFree((xmlChar *)ns->prefix);
		ns->prefix = xmlStrdup((xmlChar *)[name UTF8String]);
		
		return;
	}
	
	// The xmlNodeSetName function works for both nodes and attributes
	xmlNodeSetName(_node, (xmlChar *)[name UTF8String]);
}

- (NSString *)stringValue
{
	if ([self kind] == CXMLNamespaceKind)
	{
		return [NSString stringWithUTF8String:((const char *)((xmlNsPtr)_node)->href)];
	}
	
	if ([self kind] == CXMLAttributeKind)
	{
		xmlAttrPtr attr = (xmlAttrPtr)_node;
		
		if (attr->children != NULL)
		{
			return [NSString stringWithUTF8String:(const char *)attr->children->content];
		}
		
		return nil;
	}
	
	if (_CXMLKindIsNode([self kind]))
	{
		xmlChar *content = xmlNodeGetContent((xmlNodePtr)_node);
		
		NSString *result = [NSString stringWithUTF8String:(const char *)content];
		xmlFree(content);
		
		return result;
	}
	
	return nil;
}

- (void)setStringValue:(NSString *)string
{
	if ([self kind] == CXMLNamespaceKind)
	{
		xmlNsPtr ns = (xmlNsPtr)_node;
		
		xmlFree((xmlChar *)ns->href);
		ns->href = xmlEncodeSpecialChars(NULL, (xmlChar *)[string UTF8String]);
		
		return;
	}
	
	if ([self kind] == CXMLAttributeKind)
	{
		xmlAttrPtr attr = (xmlAttrPtr)_node;
		
		if (attr->children != NULL)
		{
			xmlChar *escapedString = xmlEncodeSpecialChars(attr->doc, (xmlChar *)[string UTF8String]);
			xmlNodeSetContent((xmlNodePtr)attr, escapedString);
			xmlFree(escapedString);
		}
		else
		{
			xmlNodePtr text = xmlNewText((xmlChar *)[string UTF8String]);
			attr->children = text;
		}
		
		return;
	}
	
	if (_CXMLKindIsNode([self kind]))
	{	
		// Setting the content of a node erases any existing child nodes.
		// Therefore, we need to remove them properly first.
		[[self class] removeAllChildrenFromNode:_node];
		
		xmlChar *escapedString = xmlEncodeSpecialChars(_node->doc, (xmlChar *)[string UTF8String]);
		xmlNodeSetContent(_node, escapedString);
		xmlFree(escapedString);
		
		return;
	}
}

- (NSUInteger)index
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	if ([self kind] == CXMLNamespaceKind)
	{
		if (_namespaceParent == NULL) return 0;
		
		xmlNsPtr currentNamespace = _namespaceParent->nsDef;
		
		NSUInteger result = 0;
		
		while (currentNamespace != NULL) {
			if (currentNamespace == (xmlNsPtr)_node) return result;
			
			result++;
			currentNamespace = currentNamespace->next;
		}
		
		return 0;
	}
	
	xmlNodePtr currentNode = _node->prev;
	
	NSUInteger index;
	for (index = 0; currentNode != NULL; ++index, currentNode = currentNode->prev);
	return index;
}

- (NSUInteger)level
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	xmlNodePtr theCurrentNode = _node->parent;
	
	NSUInteger level;
	for (level = 0; theCurrentNode != NULL; ++level, theCurrentNode = theCurrentNode->parent);
	return level;
}

- (CXMLDocument *)rootDocument
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	return(_node->doc->_private);
}

- (CXMLNode *)parent
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	if (_node->parent == NULL)
		return(NULL);
	else
		return (_node->parent->_private);
}

- (NSUInteger)childCount
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	xmlNodePtr theCurrentNode = _node->children;
	NSUInteger N;
	for (N = 0; theCurrentNode != NULL; ++N, theCurrentNode = theCurrentNode->next)
		;
	return(N);
}

- (NSArray *)children
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	NSMutableArray *theChildren = [NSMutableArray array];
	xmlNodePtr theCurrentNode = _node->children;
	while (theCurrentNode != NULL)
	{
		CXMLNode *theNode = [CXMLNode nodeWithLibXMLNode:theCurrentNode];
		[theChildren addObject:theNode];
		theCurrentNode = theCurrentNode->next;
	}
	return(theChildren);      
}

- (CXMLNode *)childAtIndex:(NSUInteger)index
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	xmlNodePtr theCurrentNode = _node->children;
	NSUInteger N;
	for (N = 0; theCurrentNode != NULL && N != index; ++N, theCurrentNode = theCurrentNode->next)
		;
	if (theCurrentNode)
		return([CXMLNode nodeWithLibXMLNode:theCurrentNode]);
	return(NULL);
}

- (CXMLNode *)previousSibling
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	if (_node->prev == NULL)
		return(NULL);
	else
		return([CXMLNode nodeWithLibXMLNode:_node->prev]);
}

- (CXMLNode *)nextSibling
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	if (_node->next == NULL)
		return(NULL);
	else
		return([CXMLNode nodeWithLibXMLNode:_node->next]);
}

//- (CXMLNode *)previousNode;
//- (CXMLNode *)nextNode;
//- (NSString *)XPath;

- (NSString *)localName
{
	if ([self kind] == CXMLNamespaceKind)
	{
		// Strangely enough, the localName of a namespace is the prefix, and the prefix is an empty string
		
		xmlNsPtr ns = (xmlNsPtr)_node;
		
		if (ns->prefix != NULL)
			return [NSString stringWithUTF8String:((const char *)ns->prefix)];
		
		return @"";
	}
	
	return [[self class] localNameForName:[self name]];
}

- (NSString *)prefix
{
	if ([self kind] == CXMLNamespaceKind)
	{
		// Strangely enough, the localName of a namespace is the prefix, and the prefix is an empty string
		return @"";
	}
	
	return [[self class] prefixForName:[self name]];
}

- (NSString *)URI
{
	if ([self kind] == CXMLAttributeKind)
	{
		xmlAttrPtr attr = (xmlAttrPtr)_node;
		
		if (attr->ns != NULL)
		{
			return [NSString stringWithUTF8String:((const char *)attr->ns->href)];
		}
	}
	else if (_CXMLKindIsNode([self kind]))
	{
		xmlNodePtr node = (xmlNodePtr)_node;
		
		if (node->ns != NULL)
		{
			return [NSString stringWithUTF8String:((const char *)node->ns->href)];
		}
	}
	
	return nil;
}

+ (NSString *)localNameForName:(NSString *)name {
	if (name == nil) return nil;
	
	NSRange range = [name rangeOfString:@":"];
	if (range.length == 0) return name;
		
	return [name substringFromIndex:range.location];
}

+ (NSString *)prefixForName:(NSString *)name
{
	if (name == nil) return nil;
	
	NSRange range = [name rangeOfString:@":"];
	if (range.length == 0) return nil;
		
	return [name substringToIndex:range.location];
}

//+ (NSString *)localNameForName:(NSString *)name;
//+ (NSString *)prefixForName:(NSString *)name;
//+ (CXMLNode *)predefinedNamespaceForPrefix:(NSString *)name;

- (NSString *)description
{
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	return([NSString stringWithFormat:@"<%@ %p [%p] %@ %@>", NSStringFromClass([self class]), self, self->_node, [self name], [self XMLStringWithOptions:0]]);
}

- (NSString *)XMLString
{
	return([self XMLStringWithOptions:0]);
}

- (NSString*)_XMLStringWithOptions:(NSUInteger)options appendingToString:(NSMutableString*)str
{
#pragma unused (options)
	
	id value = NULL;
	switch([self kind])
	{
		case CXMLAttributeKind:
			value = [NSMutableString stringWithString:[self stringValue]];
			[value replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [value length])];
			[str appendFormat:@" %@=\"%@\"", [self name], value];
			break;
		case CXMLTextKind:
			[str appendString:[self stringValue]];
			break;
		case XML_COMMENT_NODE:
		case XML_CDATA_SECTION_NODE:
			// TODO: NSXML does not have XML_CDATA_SECTION_NODE correspondent.
			break;
		default:
			NSAssert1(NO, @"TODO not implemented type (%d).",  [self kind]);
	}
	return str;
}

- (NSString *)XMLStringWithOptions:(NSUInteger)options
{
	return [self _XMLStringWithOptions:options appendingToString:[NSMutableString string]];
}
//- (NSString *)canonicalXMLStringPreservingComments:(BOOL)comments;

- (NSArray *)nodesForXPath:(NSString *)xpath error:(NSError **)error
{
#pragma unused (error)
	
	NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
	
	NSArray *theResult = NULL;
	
	xmlXPathContextPtr theXPathContext = xmlXPathNewContext(_node->doc);
	theXPathContext->node = _node;
	
	// TODO considering putting xmlChar <-> UTF8 into a NSString category
	xmlXPathObjectPtr theXPathObject = xmlXPathEvalExpression((const xmlChar *)[xpath UTF8String], theXPathContext);
	if (xmlXPathNodeSetIsEmpty(theXPathObject->nodesetval))
		theResult = [NSArray array]; // TODO better to return NULL?
	else
	{
		NSMutableArray *theArray = [NSMutableArray array];
		int N;
		for (N = 0; N < theXPathObject->nodesetval->nodeNr; N++)
		{
			xmlNodePtr theNode = theXPathObject->nodesetval->nodeTab[N];
			[theArray addObject:[CXMLNode nodeWithLibXMLNode:theNode]];
		}
		
		theResult = theArray;
	}
	
	xmlXPathFreeObject(theXPathObject);
	xmlXPathFreeContext(theXPathContext);
	return(theResult);
}

//- (NSArray *)objectsForXQuery:(NSString *)xquery constants:(NSDictionary *)constants error:(NSError **)error;
//- (NSArray *)objectsForXQuery:(NSString *)xquery error:(NSError **)error;


@end
