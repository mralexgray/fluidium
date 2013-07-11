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

#import "FUPlugIn.h"
#import "FUWindow.h"
#import "FUWindowController.h"
#import "FUDocumentController.h"

@interface FUPlugIn ()
@property (nonatomic, readwrite, retain) NSArray *viewControllers;
@end

@implementation FUPlugIn

- (id)init {
    NSAssert1(0, @"%@  must be created with an api", [self class]);
    [self release];
    return self;
}


- (id)initWithPlugInAPI:(id <FUPlugInAPI>)api { NSLog(@"cmd:%@", NSStringFromClass([(NSObject*)api class]));
    if (self = [super init]) {
        self.preferredHorizontalSplitPosition = 220;
        self.preferredVerticalSplitPosition = 220;
        self.viewControllers = [NSMutableArray array];
        self.wantsToolbarButton = YES;
        self.wantsMainMenuItem = YES;
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.viewControllers = nil;
    self.preferencesViewController = nil;
    self.identifier = nil;
    self.localizedTitle = nil;
    self.preferredMenuItemKeyEquivalent = nil;
    self.toolbarIconImageName = nil;
    self.preferencesIconImageName = nil;
    self.defaultsDictionary = nil;
    self.aboutInfoDictionary = nil;
    [super dealloc];
}


- (NSViewController *)newPlugInViewController {
    NSAssert1(0, @"%s is abstract and must be overridden", __PRETTY_FUNCTION__);
    return nil;
}


- (FUWindowController *)windowControllerForViewController:(NSViewController *)vc {
    NSParameterAssert([viewControllers containsObject:vc]);
    
    NSWindow *win = [vc.view window];
    if ([win isKindOfClass:[FUWindow class]]) {
        return [win windowController];
    } else {
        return [[FUDocumentController instance] frontWindowController];
    }
}

@synthesize viewControllers;
@synthesize preferencesViewController;
@synthesize identifier;
@synthesize localizedTitle;
@synthesize allowedViewPlacement;
@synthesize preferredViewPlacement;
@synthesize preferredMenuItemKeyEquivalent;
@synthesize preferredMenuItemKeyEquivalentModifierFlags;
@synthesize toolbarIconImageName;
@synthesize preferencesIconImageName;
@synthesize defaultsDictionary;
@synthesize aboutInfoDictionary;
@synthesize preferredVerticalSplitPosition;
@synthesize preferredHorizontalSplitPosition;
@synthesize sortOrder;
@synthesize wantsToolbarButton;
@synthesize wantsMainMenuItem;
@end
