//
//  TDComboField+FUAdditions.m
//  Fluidium
//
//  Created by Todd Ditchendorf on 6/11/10.
//  Copyright 2010 Todd Ditchendorf. All rights reserved.
//

#import "TDComboField+FUAdditions.h"
#import "WebIconDatabase.h"
#import "WebIconDatabase+FUAdditions.h"

@implementation TDComboField (FUAdditions)

- (void)showDefaultIcon {
    [self setImage:[[WebIconDatabase sharedIconDatabase] defaultFavicon]];
}

@end
