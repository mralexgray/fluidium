// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSMutableArray-OFExtensions.h"

typedef NSComparisonResult (*comparisonMethodIMPType)(id rcvr, SEL _cmd, id other);
struct selectorAndIMP {
    SEL selector;
    comparisonMethodIMPType implementation;
};

static NSComparisonResult compareWithSelectorAndIMP(id obj1, id obj2, void *context)
{
    return (((struct selectorAndIMP *)context) -> implementation)(obj1, (((struct selectorAndIMP *)context) -> selector), obj2);
}

@implementation NSMutableArray (OFExtensions)

- (void)insertObject:anObject inArraySortedUsingSelector:(SEL)selector;
{
    NSUInteger objectIndex = [self indexWhereObjectWouldBelong:anObject inArraySortedUsingSelector:selector];
    [self insertObject:anObject atIndex:objectIndex];
}    

- (NSUInteger)indexWhereObjectWouldBelong:(id)anObject inArraySortedUsingSelector:(SEL)selector;
{
    struct selectorAndIMP selAndImp;
    
    //OBASSERT([anObject respondsToSelector:selector]);
    
    selAndImp.selector = selector;
    selAndImp.implementation = (comparisonMethodIMPType)[anObject methodForSelector:selector];
    
    return [self indexWhereObjectWouldBelong:anObject inArraySortedUsingFunction:compareWithSelectorAndIMP context:&selAndImp];
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
