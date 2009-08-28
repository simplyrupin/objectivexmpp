//
//  DDXMLNode+Additions.m
//  KissXML
//
//  Created by Keith Duncan on 25/08/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "DDXMLNode+Additions.h"

#import "DDXMLNode+Private.h"
#import "NSString+Additions.h"

#import <libxml/xpath.h>
#import <libxml/xpathinternals.h>

@implementation DDXMLNode (Additions)

- (NSArray *)nodesForXPath:(NSString *)xpath namespaces:(NSDictionary *)prefixMapping error:(NSError **)errorRef;
{
	xmlXPathContextPtr xpathCtx;
	xmlXPathObjectPtr xpathObj;
	
	BOOL isTempDoc = NO;
	xmlDocPtr doc;
	
	if([DDXMLNode isXmlDocPtr:genericPtr])
	{
		doc = (xmlDocPtr)genericPtr;
	}
	else if([DDXMLNode isXmlNodePtr:genericPtr])
	{
		doc = ((xmlNodePtr)genericPtr)->doc;
		
		if(doc == NULL)
		{
			isTempDoc = YES;
			
			doc = xmlNewDoc(NULL);
			xmlDocSetRootElement(doc, (xmlNodePtr)genericPtr);
		}
	}
	else
	{
		return nil;
	}
	
	xpathCtx = xmlXPathNewContext(doc);
	xpathCtx->node = (xmlNodePtr)genericPtr;
	
	xmlNodePtr rootNode = (doc)->children;
	if(rootNode != NULL)
	{
		xmlNsPtr ns = rootNode->nsDef;
		while(ns != NULL)
		{
			xmlXPathRegisterNs(xpathCtx, ns->prefix, ns->href);
			
			ns = ns->next;
		}
	}
	
	for (NSString *currentPrefix in prefixMapping)
	{
		xmlXPathRegisterNs(xpathCtx, [currentPrefix xmlChar], [[prefixMapping objectForKey:currentPrefix] xmlChar]);
	}
	
	xpathObj = xmlXPathEvalExpression([xpath xmlChar], xpathCtx);
	
	NSArray *result;
	
	if(xpathObj == NULL)
	{
		if (errorRef != NULL) *errorRef = [[self class] lastError];
		result = nil;
	}
	else
	{
		if (errorRef != NULL) *errorRef = nil;
		
		int count = xmlXPathNodeSetGetLength(xpathObj->nodesetval);
		
		if(count == 0)
		{
			result = [NSArray array];
		}
		else
		{
			NSMutableArray *mResult = [NSMutableArray arrayWithCapacity:count];
			
			int i;
			for (i = 0; i < count; i++)
			{
				xmlNodePtr node = xpathObj->nodesetval->nodeTab[i];
				
				[mResult addObject:[DDXMLNode nodeWithPrimitive:(xmlKindPtr)node]];
			}
			
			result = mResult;
		}
	}
	
	if (xpathObj) xmlXPathFreeObject(xpathObj);
	if (xpathCtx) xmlXPathFreeContext(xpathCtx);
	
	if(isTempDoc)
	{
		xmlUnlinkNode((xmlNodePtr)genericPtr);
		xmlFreeDoc(doc);
		
		// xmlUnlinkNode doesn't remove the doc ptr
		[[self class] recursiveStripDocPointersFromNode:(xmlNodePtr)genericPtr];
	}
	
	return result;
}

@end
