//
//  FUSetFormValuesCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 7/18/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUSetFormValuesCommand.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"

@implementation FUSetFormValuesCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleSetFormValuesCommand:self];
}

@end
