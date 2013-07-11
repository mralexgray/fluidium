// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OBObject.h"

@implementation OBObject
@end

@implementation NSObject (OBDebuggingExtensions)

/*"
 Returns a mutable dictionary describing the contents of the object. Subclasses should override this method, call the superclass implementation, and then add their contents to the returned dictionary. This is used for debugging purposes. It is highly recommended that you subclass this method in order to add information about your custom subclass (if appropriate), as this has no performance or memory requirement issues (it is never called unless you specifically call it, presumably from withing a gdb debugging session).
 
 See also: - shortDescription (NSObject)
 "*/
- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[self shortDescription] forKey:@"__self__"];
    return dict;
}

/*"
 Returns -description but can be customized to return some small amount of extra information about the instance itself (though not its contents).

 See also: - description (NSObject)
 "*/
- (NSString *)shortDescription;
{
    return [self description];
}

@end

// These are defined on other NSObject subclasses; extend OBObject to have them using our -debugDictionary and -shortDescription
@implementation OBObject (OBDebugging)

static const unsigned int MaxDebugDepth = 3;

/*"
Normally, calls [self debugDictionary], asks that dictionary to perform descriptionWithLocale:indent:, and returns the result. To minimize the chance of the resulting description being extremely large (and therefore more confusing than useful), if level is greater than 2 this method simply returns [self shortDescription].

See also: - debugDictionary
"*/
- (NSString *)descriptionWithLocale:(NSDictionary *)locale indent:(NSUInteger)level
{
    if (level < MaxDebugDepth)
        return [[self debugDictionary] descriptionWithLocale:locale indent:level];
    return [self shortDescription];
}

/*" Returns [self descriptionWithLocale:nil indent:0]. This often provides more meaningful information than the default implementation of description, and is (normally) automatically used by the debugger, gdb, when asked to print an object.

 See also: - description (NSObject), - shortDescription
"*/
- (NSString *)description;
{
    return [self descriptionWithLocale:nil indent:0];
}

/*"
 Returns [super description].  Without this, the NSObject -shortDescription would call our -description which could eventually recurse to -shortDescription.
 
 See also: - description (NSObject)
 "*/
- (NSString *)shortDescription;
{
    return [super description];
}

@end
