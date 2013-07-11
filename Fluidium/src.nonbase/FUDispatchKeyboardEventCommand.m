//
//  FUDispatchKeyboardEventCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 7/13/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUDispatchKeyboardEventCommand.h"
#import "FUDocumentController.h"
#import "FUTabController+Scripting.h"

@implementation FUDispatchKeyboardEventCommand

- (id)performDefaultImplementation {
    NSDictionary *args = [self evaluatedArguments];
    
    FUTabController *tc = [args objectForKey:@"tabController"]; // may be nil
    if (!tc) {
        tc = [[FUDocumentController instance] frontTabController];
    }
    [tc handleDispatchKeyboardEventCommand:self];
    
    return nil;
}

@end
