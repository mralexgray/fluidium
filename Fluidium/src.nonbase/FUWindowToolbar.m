//  Copyright 2009 Todd Ditchendorf
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "FUWindowToolbar.h"
#import "FUNotifications.h"
#import "FUUserDefaults.h"

@interface FUWindowToolbar ()
- (void)postToolbarShownNotification;
@end

@implementation FUWindowToolbar

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    self.window = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark NSToolbar

- (void)setVisible:(BOOL)yn {
    [super setVisible:yn];
    if (suppressNextToolbarShownChange) {
        suppressNextToolbarShownChange = NO;
    } else {
        [[FUUserDefaults instance] setToolbarShown:yn];
    }
    [self performSelector:@selector(postToolbarShownNotification) withObject:nil afterDelay:0];
}


#pragma mark -
#pragma mark Public

- (void)showTemporarily {
    suppressNextToolbarShownChange = YES;
    [self setVisible:YES];
}


#pragma mark -
#pragma mark Private

- (void)postToolbarShownNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:FUToolbarShownDidChangeNotification object:window];
}

@synthesize window;
@end
