// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSArray-OFExtensions.h"
#import <objc/objc.h>

typedef NSComparisonResult (*comparisonMethodIMPType)(id rcvr, SEL _cmd, id other);
struct selectorAndIMP {
    SEL selector;
    comparisonMethodIMPType implementation;
};

static NSComparisonResult compareWithSelectorAndIMP(id obj1, id obj2, void *context)
{
    return (((struct selectorAndIMP *)context) -> implementation)(obj1, (((struct selectorAndIMP *)context) -> selector), obj2);
}

@implementation NSArray (OFExtensions)

- (BOOL)containsObjectIdenticalTo:(id)anObject;
{
    return [self indexOfObjectIdenticalTo:anObject] != NSNotFound;
}


- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inArraySortedUsingSelector:(SEL)selector;
{
    struct selectorAndIMP selAndImp;
    
    selAndImp.selector = selector;
    selAndImp.implementation = (comparisonMethodIMPType)[anObject methodForSelector:selector];
    
    return [self indexOfObject:anObject identical:YES inArraySortedUsingFunction:compareWithSelectorAndIMP context:&selAndImp];
}


- (NSUInteger)indexOfObject:(id)anObject identical:(BOOL)requireIdentity inArraySortedUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    IMP objectAtIndexImp = [self methodForSelector:@selector(objectAtIndex:)];
    NSUInteger objectIndex = [self indexWhereObjectWouldBelong:anObject inArraySortedUsingFunction:comparator context:context];
    NSUInteger count = [self count];
    id compareWith;
    
    if (objectIndex == count)
        return NSNotFound;
    
    if (requireIdentity) {            
        NSUInteger startingAtIndex = objectIndex;
        do {
            compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
            if (compareWith == anObject) 
                return objectIndex;
            if (comparator(anObject, compareWith, context) != NSOrderedSame)
                break;
        } while (objectIndex--);
        
        objectIndex = startingAtIndex;
        while (++objectIndex < count) {
            compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
            if (compareWith == anObject)
                return objectIndex;
            if (comparator(anObject, compareWith, context) != NSOrderedSame)
                break;
        }
    } else {
        compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
        if ((NSComparisonResult)comparator(anObject, compareWith, context) == NSOrderedSame)
            return objectIndex;
    }
    return NSNotFound;
}

- (NSUInteger)indexWhereObjectWouldBelong:(id)anObject inArraySortedUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    unsigned int low = 0;
    unsigned int range = 1;
    unsigned int test = 0;
    unsigned int count = [self count];
    NSComparisonResult result;
    id compareWith;
    IMP objectAtIndexImp = [self methodForSelector:@selector(objectAtIndex:)];
    
    while (count >= range) /* range is the lowest power of 2 > count */
        range <<= 1;
    
    while (range) {
        test = low + (range >>= 1);
        if (test >= count)
            continue;
        compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), test);
        if (compareWith == anObject) 
            return test;
        result = (NSComparisonResult)comparator(anObject, compareWith, context);
        if (result > 0) /* NSOrderedDescending */
            low = test+1;
        else if (result == NSOrderedSame) 
            return test;
    }
    return low;
}

@end
