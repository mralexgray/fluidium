//
//  FUClickLinkCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 2/20/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUClickLinkCommand.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"

@implementation FUClickLinkCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleClickLinkCommand:self];
}

@end