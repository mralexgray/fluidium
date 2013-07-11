// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSObject-OFExtensions.h"

@implementation NSObject (OFExtensions)

+ (NSBundle *)bundle {
    return [NSBundle bundleForClass:[self class]];
}

- (NSString *)shortDescription {
    return [self description];
}

@end
