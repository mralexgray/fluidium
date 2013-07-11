//
//  FUSetElementValueCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 2/20/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUSetElementValueCommand.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"

@implementation FUSetElementValueCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleSetElementValueCommand:self];
}

@end
