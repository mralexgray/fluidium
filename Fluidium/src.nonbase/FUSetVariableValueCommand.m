//
//  FUSetVariableValueCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 7/16/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUSetVariableValueCommand.h"
#import "FUTabController+Scripting.h"

@implementation FUSetVariableValueCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleSetVariableValueCommand:self];
}

@end
