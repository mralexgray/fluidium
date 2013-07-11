//
//  FUFocusElementCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 7/12/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUFocusElementCommand.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"

@implementation FUFocusElementCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleFocusElementCommand:self];
}

@end
