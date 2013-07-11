//
//  FUClickButtonCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 2/20/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUClickButtonCommand.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"

@implementation FUClickButtonCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleClickButtonCommand:self];
}

@end