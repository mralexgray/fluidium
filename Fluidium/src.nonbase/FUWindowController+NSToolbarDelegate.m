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

#import "FUWindowController+NSToolbarDelegate.h"
#import "FUWindowController.h"
#import "FUTabController.h"
#import "FUDocument+Scripting.h"
#import "FUApplication.h"
#import "FUUserDefaults.h"
#import "FUWindowToolbar.h"
#import "FUBackForwardPopUpButton.h"
#import "FUPlugInController.h"
#import "FUPlugInWrapper.h"
#import "WebViewPrivate.h"
#import <WebKit/WebKit.h>

#define FAKE_PLUGIN_ID @"com.fakeapp.FakePlugIn"

#define BACK_TAG 500
#define FORWARD_TAG 510
#define RELOAD_TAG 520
#define STOP_TAG 530
#define HOME_TAG 540
#define SMALLER_TAG 550
#define LARGER_TAG 560

static NSString *const FUBackItemIdentifier = @"FUBackItemIdentifier";
static NSString *const FUForwardItemIdentifier = @"FUForwardItemIdentifier";
static NSString *const FUReloadItemIdentifier = @"FUReloadItemIdentifier";
static NSString *const FUStopItemIdentifier = @"FUStopItemIdentifier";
static NSString *const FUHomeItemIdentifier = @"FUHomeItemIdentifier";
static NSString *const FULocationItemIdentifier = @"FULocationItemIdentifier";
static NSString *const FUTextSmallerItemIdentifier = @"FUTextSmallerItemIdentifier";
static NSString *const FUTextLargerItemIdentifier = @"FUTextLargerItemIdentifier";

@interface FUWindowController (NSToolbarDelegatePrivate)
- (NSToolbarItem *)toolbarItemForPlugInWrapper:(FUPlugInWrapper *)wrap;
- (NSToolbarItem *)buttonToolbarItemWithIdentifier:(NSString *)itemID imageNamed:(NSString *)name label:(NSString *)label target:(id)target action:(SEL)sel tag:(NSInteger)tag;
- (NSToolbarItem *)buttonToolbarItemWithIdentifier:(NSString *)itemID image:(NSImage *)img label:(NSString *)label target:(id)target action:(SEL)sel tag:(NSInteger)tag;
- (NSToolbarItem *)viewToolbarItemWithIdentifier:(NSString *)itemID view:(NSView *)view label:(NSString *)label target:(id)target action:(SEL)sel;
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier label:(NSString *)label;
- (NSArray *)allPlugInToolbarItemIdentifiers;
@end

@implementation FUWindowController (NSToolbarDelegate)

- (void)setUpToolbar {
    FUWindowToolbar *toolbar = [[[FUWindowToolbar alloc] initWithIdentifier:@"FUWindowToolbar"] autorelease];
    [toolbar setShowsBaselineSeparator:NO];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setAutosavesConfiguration:YES];
    [[self window] setToolbar:toolbar];
    [toolbar setWindow:[self window]];
    [toolbar setVisible:[[FUUserDefaults instance] toolbarShown]];
}


#pragma mark -
#pragma mark NSToolbarItemValidation

//- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
//    switch ([item tag]) {
//        case BACK_TAG:
//            return [[selectedTabController webView] canGoBack];
//        case FORWARD_TAG:
//            return [[selectedTabController webView] canGoForward];
//        case RELOAD_TAG:
//            return [[selectedTabController webView] canReload];
//        case STOP_TAG:
//            return [[selectedTabController webView] isLoading];
//        case HOME_TAG:
//            return nil != selectedTabController;
//        case SMALLER_TAG:
//            if ([[FUUserDefaults instance] zoomTextOnly]) {
//                return [[selectedTabController webView] canMakeTextSmaller];
//            } else {
//                return [[selectedTabController webView] canZoomPageOut];
//            }
//        case LARGER_TAG:
//            if ([[FUUserDefaults instance] zoomTextOnly]) {
//                return [[selectedTabController webView] canMakeTextLarger];
//            } else {
//                return [[selectedTabController webView] canZoomPageIn];
//            }
//        default:
//            return YES;
//    }
//}


#pragma mark -
#pragma mark NSToolbarDelegate

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)tb {
    NSMutableArray *a = [NSMutableArray arrayWithObjects:
                         FUBackItemIdentifier,
                         FUForwardItemIdentifier,
                         FUReloadItemIdentifier,
                         FUStopItemIdentifier,
                         FUHomeItemIdentifier, 
                         FULocationItemIdentifier,
                         nil];

    NSArray *plugInIds = [self allPlugInToolbarItemIdentifiers];
    [a addObjectsFromArray:plugInIds];
    return a;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)tb {
    NSMutableArray *a = [NSMutableArray arrayWithObjects:
                         NSToolbarPrintItemIdentifier,
                         NSToolbarCustomizeToolbarItemIdentifier,
                         NSToolbarFlexibleSpaceItemIdentifier,
                         NSToolbarSpaceItemIdentifier,
                         NSToolbarSeparatorItemIdentifier, 
                         FUBackItemIdentifier,
                         FUForwardItemIdentifier,
                         FUTextSmallerItemIdentifier,
                         FUTextLargerItemIdentifier,
                         FUReloadItemIdentifier,
                         FUStopItemIdentifier,
                         FUHomeItemIdentifier, 
                         FULocationItemIdentifier,
                         nil];    

    NSArray *plugInIds = [self allPlugInToolbarItemIdentifiers];
    [a addObjectsFromArray:plugInIds];
    return a;
}


- (NSToolbarItem *)toolbar:(NSToolbar *)tb itemForItemIdentifier:(NSString *)itemID willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = nil;
    NSString *name = nil;
    BOOL isFullScreen = [[FUApplication instance] isFullScreen];

    if ([itemID isEqualToString:FUBackItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_back" : NSImageNameGoLeftTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Back", @"") target:self action:@selector(webGoBack:) tag:BACK_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.webView.canGoBack" options:nil];

    } else if ([itemID isEqualToString:FUForwardItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_fwd" : NSImageNameGoRightTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Forward", @"") target:self action:@selector(webGoForward:) tag:FORWARD_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.webView.canGoForward" options:nil];

    } else if ([itemID isEqualToString:FUReloadItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_reload" : NSImageNameRefreshTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Reload", @"") target:self action:@selector(webReload:) tag:RELOAD_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.canReload" options:nil];

    } else if ([itemID isEqualToString:FUStopItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_stop" : NSImageNameStopProgressTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Stop", @"") target:self action:@selector(webStopLoading:) tag:STOP_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.webView.isLoading" options:nil];

    } else if ([itemID isEqualToString:FUHomeItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_home" : @"toolbar_button_home";
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Home", @"") target:self action:@selector(webGoHome:) tag:HOME_TAG];

    } else if ([itemID isEqualToString:FUTextSmallerItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_smaller" : NSImageNameRemoveTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Smaller", @"") target:self action:@selector(zoomOut:) tag:SMALLER_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.webView.canMakeTextSmaller" options:nil];

    } else if ([itemID isEqualToString:FUTextLargerItemIdentifier]) {
        name = isFullScreen ? @"fullscreen_toolbar_button_larger" : NSImageNameAddTemplate;
        item = [self buttonToolbarItemWithIdentifier:itemID imageNamed:name label:NSLocalizedString(@"Larger", @"") target:self action:@selector(zoomIn:) tag:LARGER_TAG];
        [[item view] bind:@"enabled" toObject:self withKeyPath:@"selectedTabController.webView.canMakeTextLarger" options:nil];

    } else if ([itemID isEqualToString:FULocationItemIdentifier]) {
        item = [self viewToolbarItemWithIdentifier:itemID view:locationSplitView label:NSLocalizedString(@"Address / Search", @"") target:nil action:nil];
        [locationSplitView resizeSubviewsWithOldSize:NSMakeSize(0, 0)];

    } else {
        item = [self toolbarItemForPlugInWrapper:[[FUPlugInController instance] plugInWrapperForIdentifier:itemID]];

    } 
    
    return item;
}


#pragma mark -
#pragma mark Private

- (NSToolbarItem *)toolbarItemForPlugInWrapper:(FUPlugInWrapper *)wrap {
    if (!wrap) return nil;

#ifdef FAKE
    if ([wrap.identifier isEqualToString:FAKE_PLUGIN_ID]) return nil;
#endif
    
    NSBundle *bundle = [NSBundle bundleForClass:[wrap.plugIn class]];
    NSString *imgName = wrap.toolbarIconImageName;
    NSString *path = [bundle pathForImageResource:imgName];
    NSImage *img = nil;
    
    if ([path length]) {
        NSURL *URL = [NSURL fileURLWithPath:path];
        img = [[[NSImage alloc] initWithContentsOfURL:URL] autorelease];
    } 
    
    if (!img) {
        img = [NSImage imageNamed:wrap.toolbarIconImageName];
    }
    
    return [self buttonToolbarItemWithIdentifier:wrap.identifier image:img label:[wrap localizedTitle] target:[FUPlugInController instance] action:@selector(plugInMenuItemAction:) tag:-1];
}


- (NSToolbarItem *)buttonToolbarItemWithIdentifier:(NSString *)itemID imageNamed:(NSString *)name label:(NSString *)label target:(id)target action:(SEL)sel tag:(NSInteger)tag {
    return [self buttonToolbarItemWithIdentifier:itemID image:[NSImage imageNamed:name] label:label target:target action:sel tag:tag];
}


- (NSToolbarItem *)buttonToolbarItemWithIdentifier:(NSString *)itemID image:(NSImage *)img label:(NSString *)label target:(id)target action:(SEL)sel tag:(NSInteger)tag {
    NSToolbarItem *item = [self toolbarItemWithIdentifier:itemID label:label];
    [item setTag:tag];
    
    Class buttonClass = nil;
    if (@selector(webGoBack:) == sel || @selector(webGoForward:) == sel) {
        buttonClass = [FUBackForwardPopUpButton class];
    } else {
        buttonClass = [NSButton class];
    }
    
    NSButton *b = [[[buttonClass alloc] initWithFrame:NSMakeRect(0, 0, 28, 23)] autorelease];
    [[b cell] setRepresentedObject:itemID];
    [b setButtonType:NSMomentaryPushInButton];
    [b setTarget:target];
    [b setAction:sel];
    
    if ([[FUApplication instance] isFullScreen]) {
        [b setBordered:NO];
    } else {
        [b setBezelStyle:NSTexturedRoundedBezelStyle];
    }
    
    [b setImage:img];
    [item setView:b];
    return item;
}


- (NSToolbarItem *)viewToolbarItemWithIdentifier:(NSString *)itemID view:(NSView *)view label:(NSString *)label target:(id)target action:(SEL)sel {    
    NSToolbarItem *item = [self toolbarItemWithIdentifier:itemID label:label];
    [item setView:view];
    [item setMinSize:NSMakeSize(80, NSHeight([view frame]))];
    [item setMaxSize:NSMakeSize(NSIntegerMax, NSHeight([view frame]))];        
    return item;
}


- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier label:(NSString *)label {
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    [item setLabel:label];
    [item setPaletteLabel:label];
    [item setAutovalidates:YES];
    return item;
}


- (NSArray *)allPlugInToolbarItemIdentifiers {
    NSArray *a = [[FUPlugInController instance] allPlugInIdentifiers];
#ifdef FAKE
    if ([a containsObject:FAKE_PLUGIN_ID]) {
        NSMutableArray *ma = [NSMutableArray arrayWithArray:a];
        [ma removeObject:FAKE_PLUGIN_ID];
        a = [[ma copy] autorelease];
    }
#endif
    return a;
}

@end
