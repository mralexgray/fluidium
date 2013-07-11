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

#import "FUUserthingWindowController.h"
#import "FUUserthingViewController.h"
#import "FUUserscriptViewController.h"
#import "FUUserstyleViewController.h"

@implementation FUUserthingWindowController

+ (FUUserthingWindowController *)instance {
    static FUUserthingWindowController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUUserthingWindowController alloc] init];
        }
    }
    return instance;
}


- (id)init {
    return [self initWithWindowNibName:@"FUUserthingWindow"];
}


- (id)initWithWindowNibName:(NSString *)name {
    if (self = [super initWithWindowNibName:name]) {
        
    }
    return self;
}


- (void)dealloc {
    self.tabView = nil;
    self.scriptContainerView = nil;
    self.styleContainerView = nil;
    self.scriptViewController = nil;
    self.styleViewController = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    self.scriptViewController = [[[FUUserscriptViewController alloc] init] autorelease];
    self.styleViewController = [[[FUUserstyleViewController alloc] init] autorelease];
    
    [scriptViewController.view setFrame:[scriptContainerView bounds]];
    [scriptContainerView addSubview:scriptViewController.view];

    [styleViewController.view setFrame:[styleContainerView bounds]];
    [styleContainerView addSubview:styleViewController.view];
}


#pragma mark -
#pragma mark Actions

- (IBAction)showUserscripts:(id)sender {
    [self showWindow:sender];
    [tabView selectTabViewItemAtIndex:0];
}


- (IBAction)showUserstyles:(id)sender {
    [self showWindow:sender];
    [tabView selectTabViewItemAtIndex:1];
}

@synthesize tabView;
@synthesize scriptContainerView;
@synthesize styleContainerView;
@synthesize scriptViewController;
@synthesize styleViewController;
@end
