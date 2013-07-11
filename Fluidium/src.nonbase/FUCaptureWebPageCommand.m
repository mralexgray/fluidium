//
//  CaptureWebPageCommand.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 7/14/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "FUCaptureWebPageCommand.h"
#import "FUTabController+Scripting.h"

@implementation FUCaptureWebPageCommand

- (id)performDefaultImplementation {
    return [[self targetTabController] handleCaptureWebPageCommand:self];
}

@end
