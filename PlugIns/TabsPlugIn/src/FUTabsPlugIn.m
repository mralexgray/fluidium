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

#import "FUTabsPlugIn.h"
#import "FUTabsViewController.h"
#import "FUTabsPreferencesViewController.h"
#import <Fluidium/FUPlugIn.h>
#import <Fluidium/FUPlugInAPI.h>
#import <Fluidium/FUNotifications.h>

@interface FUTabsPlugIn ()
@property (nonatomic, readwrite, retain) id <FUPlugInAPI>plugInAPI;
@end

@implementation FUTabsPlugIn

- (id)initWithPlugInAPI:(id <FUPlugInAPI>)api {
    if (self = [super initWithPlugInAPI:api]) {
        self.plugInAPI = api;
        self.identifier = @"com.fluidapp.TabsPlugIn";
        self.localizedTitle = NSLocalizedString(@"Tabs", @"");
        self.preferredMenuItemKeyEquivalentModifierFlags = (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
        self.toolbarIconImageName = NSImageNameIconViewTemplate;
        self.preferencesIconImageName = NSImageNameIconViewTemplate;
        self.allowedViewPlacement = (FUPlugInViewPlacementDrawer|
                                     FUPlugInViewPlacementSplitViewLeft|
                                     FUPlugInViewPlacementSplitViewRight|
                                     FUPlugInViewPlacementSplitViewTop|
                                     FUPlugInViewPlacementSplitViewBottom);
        self.preferredViewPlacement = FUPlugInViewPlacementSplitViewTop;
        self.preferredMenuItemKeyEquivalent = @"a";
        
        // get defaults from disk
//        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"DefaultValues" ofType:@"plist"];
//        self.defaultsDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
        
        self.preferencesViewController = [[[FUTabsPreferencesViewController alloc] init] autorelease];
        
        self.preferredVerticalSplitPosition = 120;
        self.preferredHorizontalSplitPosition = 84;
        self.sortOrder = 200;
    }
    return self;
}


- (void)dealloc {
    self.plugInAPI = nil;
    [super dealloc];
}


- (void)plugInViewControllerWillAppear:(NSNotification *)n {
    [[n object] viewWillAppear];
}


- (void)plugInViewControllerDidAppear:(NSNotification *)n {
    [[n object] viewDidAppear];
}


- (void)plugInViewControllerWillDisappear:(NSNotification *)n {
    [[n object] viewWillDisappear];
}


- (NSViewController *)newPlugInViewController {
    FUTabsViewController *vc = [[FUTabsViewController alloc] init];
    vc.plugIn = self;
    vc.plugInAPI = plugInAPI;
    return vc;
}


- (NSDictionary *)aboutInfoDictionary {
    if (!aboutInfoDictionary) {
        NSAttributedString *credits = [[[NSAttributedString alloc] initWithString:@"" attributes:nil] autorelease];
        NSString *applicationName = [NSString stringWithFormat:@"%@ Tabs Plug-in", [plugInAPI appName]];

        NSImage  *applicationIcon = [NSImage imageNamed:self.preferencesIconImageName];
        
        NSString *version = @"1.0";
        NSString *copyright = @"Todd Ditchendorf 2010";
        NSString *applicationVersion = @"1.0";
        
        self.aboutInfoDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    credits, @"Credits",
                                    applicationName, @"ApplicationName",
                                    applicationIcon, @"ApplicationIcon",
                                    version, @"Version",
                                    copyright, @"Copyright",
                                    applicationVersion, @"ApplicationVersion",
                                    nil];
    }
    return aboutInfoDictionary;
}

@synthesize plugInAPI;
@end
