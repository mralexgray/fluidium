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

#import "FUPlugInController.h"
#import "FUPlugIn.h"
#import "FUPlugInWrapper.h"
#import "FUPlugInController.h"
#import "FUPlugInAPIImpl.h"
#import "FUWindowController.h"
#import "FUDocument.h"
#import "FUDocumentController.h"
#import "FUApplication.h"
#import "FUUserDefaults.h"
#import "FUPlugInPreferences.h"
#import "FUNotifications.h"
#import "NSFileManager+FUAdditions.h"
#import <WebKit/WebKit.h>
#import "OAPreferenceController.h"
#import "OAPreferenceClient.h"
#import <TDAppKit/TDUberView.h>

#define PLUGIN_MENU_INDEX 6
#define MIN_PREFS_VIEW_WIDTH 427
#define PREFS_VIEW_VERTICAL_FUDGE 47

NSString *const FUPlugInViewControllerWillAppearNotifcation = @"FUPlugInViewControllerWillAppearNotifcation";
NSString *const FUPlugInViewControllerDidAppearNotifcation = @"FUPlugInViewControllerDidAppearNotifcation";
NSString *const FUPlugInViewControllerWillDisappearNotifcation = @"FUPlugInViewControllerWillDisappearNotifcation";
NSString *const FUPlugInViewControllerDidDisappearNotifcation = @"FUPlugInViewControllerDidDisappearNotifcation";

NSString *const FUPlugInViewPlacementMaskKey = @"FUPlugInViewPlacementMaskKey";
NSString *const FUPlugInKey = @"FUPlugInKey";
NSString *const FUPlugInViewControllerKey = @"FUPlugInViewControllerKey";
NSString *const FUPlugInViewControllerDrawerKey = @"FUPlugInViewControllerDrawerKey";

@interface OAPreferenceController (FUShutUpCompiler)
+ (void)registerItemName:(NSString *)itemName bundle:(NSBundle *)bundle description:(NSDictionary *)description;
@end

@interface FUPlugInController ()
- (void)windowControllerDidOpen:(NSNotification *)n;
- (void)showVisiblePlugInsInWindow:(NSWindow *)win;

- (void)loadPlugIn:(FUPlugIn *)plugIn;
- (void)loadPlugInAtPath:(NSString *)path;
- (void)loadPlugInsAtPath:(NSString *)dirPath;
- (void)registerNotificationsOnPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)setUpMenuItemsForPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)setUpPrefPanesForPlugInWrappers;
- (void)setUpPrefPaneForPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)toggleDrawerPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)window;
- (void)toggleUtilityPanelPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)toggleFloatingUtilityPanelPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)toggleHUDPanelPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)toggleFloatingHUDPanelPlugInWrapper:(FUPlugInWrapper *)wrap;
- (void)togglePanelPluginWrapper:(FUPlugInWrapper *)wrap isFloating:(BOOL)isFloating isHUD:(BOOL)isHUD;
- (NSPanel *)newPanelWithContentView:(NSView *)contentView isHUD:(BOOL)isHUD;
- (void)toggleSplitViewTopPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)window;
- (void)toggleSplitViewBottomPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)window;
- (void)toggleSplitViewLeftPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)window;
- (void)toggleSplitViewRightPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)window;
- (void)toggleSplitViewPluginWrapper:(FUPlugInWrapper *)wrap isVertical:(BOOL)isVertical isFirst:(BOOL)isFirst inWindow:(NSWindow *)window;
- (void)post:(NSString *)name forPlugInWrapper:(FUPlugInWrapper *)wrap viewController:(NSViewController *)vc;
- (void)post:(NSString *)name forPlugInWrapper:(FUPlugInWrapper *)wrap viewController:(NSViewController *)vc userInfo:(NSMutableDictionary *)userInfo;

@property (nonatomic, retain) NSMutableDictionary *allPlugInWrappersTable;
@end

@implementation FUPlugInController

+ (FUPlugInController *)instance {
    static FUPlugInController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUPlugInController alloc] init];
        }
    }
    return instance;
}


- (id)init {    
    if (self = [super init]) {
        self.windowsForPlugInIdentifier = [NSMutableDictionary dictionary];
        self.plugInAPI = [[[FUPlugInAPIImpl alloc] init] autorelease];
        self.allPlugInWrappersTable = [NSMutableDictionary dictionary];
        
        [self loadPlugIns];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowControllerDidOpen:) name:FUWindowControllerDidOpenNotification object:nil];
    }
    return self;
}


- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.plugInMenu = nil;
    self.windowsForPlugInIdentifier = nil;
    self.plugInAPI = nil;
    self.allPlugInWrappersTable = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Notifications

- (void)windowControllerDidOpen:(NSNotification *)n {
    NSWindow *win = [[n object] window];
    
    if ([[FUUserDefaults instance] showVisiblePlugInsInNewWindows]) {
        // do it in the next run loop. avoids problem where NSWindows have a windowNumber of -1 until the next runloop
        //[self performSelector:@selector(showVisiblePlugInsInWindow:) withObject:win afterDelay:0];
        [self showVisiblePlugInsInWindow:win];
    }
}


- (void)showVisiblePlugInsInWindow:(NSWindow *)win {
    for (NSString *identifier in [[FUUserDefaults instance] visiblePlugInIdentifiers]) {
        FUPlugInWrapper *wrap = [self plugInWrapperForIdentifier:identifier];
        if (wrap) { // a plugin may have been removed/uninstalled. so check for it
            [self showPlugInWrapper:wrap inWindow:win];
        }
    }
    
    FUWindowController *wc = [win windowController];
//    [[wc document] performSelector:@selector(windowControllerDidShowVisiblePlugIns:) withObject:wc afterDelay:0];
    [[wc document] windowControllerDidShowVisiblePlugIns:wc];
}


#pragma mark -

- (void)loadPlugIns {
    [self loadPlugInsAtPath:[[FUApplication instance] plugInPrivateDirPath]];
    [self loadPlugInsAtPath:[[FUApplication instance] plugInDirPath]];
    [self setUpPrefPanesForPlugInWrappers];
    [self setUpMenuItemsForPlugIns];
}


- (void)loadPlugInsAtPath:(NSString *)dirPath {


    [NSFileManager.defaultManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSMutableArray *filenames = [NSMutableArray array];    
    [filenames addObjectsFromArray:[NSFileManager.defaultManager directoryContentsAtPath:dirPath havingExtension:@"fluidplugin" error:nil]];
    
    for (NSString *filename in filenames) {
        NSString *path = [dirPath stringByAppendingPathComponent:filename];
        @try {
            [self loadPlugInAtPath:path];
        } @catch (NSException *e) {
            NSLog(@"%@ couldn't load Plug-in at path: %@\n%@", [[FUApplication instance] appName], path, [e reason]);
        }
    }
}


- (void)loadPlugInAtPath:(NSString *)path {

    NSBundle *bundle = [NSBundle bundleWithPath:path];
    FUPlugIn *plugIn = nil;

    if ([[bundle bundleIdentifier] hasPrefix:@"com.fluidapp.BrowsaPlugIn"]) {
        NSInteger num = [FUUserDefaults.instance numberOfBrowsaPlugIns];
        NSInteger i = 0;
        for ( ; i < num; i++) {
				Class c = bundle.principalClass;
				NSLog(@"Principal: %@ pluginAPI: %@", NSStringFromClass(c), plugInAPI);
            plugIn = [[c.alloc initWithPlugInAPI:plugInAPI] autorelease];
            [self loadPlugIn:plugIn];
        }
    } else {
			Class c = bundle.principalClass;
			NSLog(@"Principal: %@ pluginAPI: %@", NSStringFromClass(c), plugInAPI);
        plugIn = [[c.alloc initWithPlugInAPI:plugInAPI] autorelease];
        [self loadPlugIn:plugIn];
    }
}


- (void)loadPlugIn:(FUPlugIn *)plugIn {
    NSString *identifier = [plugIn identifier];
    
    if ([allPlugInWrappersTable objectForKey:identifier]) {
        NSLog(@"already loaded plugin with identifier: %@, ignoring", identifier);
        return;
    }
        
    FUPlugInWrapper *wrap = [[[FUPlugInWrapper alloc] initWithPlugIn:plugIn] autorelease];
    [allPlugInWrappersTable setObject:wrap forKey:identifier];
    
    [self registerNotificationsOnPlugInWrapper:wrap];
}


- (void)setUpMenuItemsForPlugIns {
    NSMenuItem *item = [[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Plug-ins", @"")];
    if (item) {
        self.plugInMenu = [item submenu];
        
        for (FUPlugInWrapper *wrap in [self plugInWrappers]) {
            [self setUpMenuItemsForPlugInWrapper:wrap];
        }
    }
}


- (void)setUpMenuItemsForPlugInWrapper:(FUPlugInWrapper *)wrap {
    NSString *identifier = wrap.identifier;
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"%@ Plug-in", @""), wrap.localizedTitle];
    
    NSMenuItem *aboutMenuItem = [[[NSMenuItem alloc] initWithTitle:title
                                                            action:@selector(plugInAboutMenuItemAction:)
                                                     keyEquivalent:@""] autorelease];
    [aboutMenuItem setTarget:self];
    [aboutMenuItem setRepresentedObject:identifier];
    [[[plugInMenu itemAtIndex:0] submenu] addItem:aboutMenuItem];
    
    if (wrap.wantsMainMenuItem) {
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title
                                                           action:@selector(plugInMenuItemAction:)
                                                    keyEquivalent:wrap.preferredMenuItemKeyEquivalent] autorelease];
        [menuItem setKeyEquivalentModifierMask:wrap.preferredMenuItemKeyEquivalentModifierFlags];
        [menuItem setTarget:self];
        [menuItem setRepresentedObject:identifier];
        //[menuItem setImage:[NSImage imageNamed:[plugIn iconImageName]]];
        [plugInMenu addItem:menuItem];
    }
}


- (void)registerNotificationsOnPlugInWrapper:(FUPlugInWrapper *)wrap {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    SEL selector = nil;
    
    selector = @selector(plugInViewControllerWillAppear:);
    if ([wrap respondsToSelector:selector]) {
        [nc addObserver:wrap 
               selector:selector
                   name:FUPlugInViewControllerWillAppearNotifcation
                 object:wrap];
    }
    
    selector = @selector(plugInViewControllerDidAppear:);
    if ([wrap respondsToSelector:selector]) {
        [nc addObserver:wrap 
               selector:selector
                   name:FUPlugInViewControllerDidAppearNotifcation
                 object:wrap];
    }
    
    selector = @selector(plugInViewControllerWillDisappear:);
    if ([wrap respondsToSelector:selector]) {
        [nc addObserver:wrap 
               selector:selector
                   name:FUPlugInViewControllerWillDisappearNotifcation
                 object:wrap];
    }
    
    selector = @selector(plugInViewControllerDidDisappear:);
    if ([wrap respondsToSelector:selector]) {
        [nc addObserver:wrap 
               selector:selector
                   name:FUPlugInViewControllerDidDisappearNotifcation
                 object:wrap];    
    }
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (@selector(plugInAboutMenuItemAction:) == [menuItem action]) {
        FUPlugInWrapper *wrap = [self plugInWrapperForIdentifier:[menuItem representedObject]];
        
        return (nil != wrap.aboutInfoDictionary);
    } else {
        return YES;
    }
}


- (void)setUpPrefPanesForPlugInWrappers {
    //[OAPreferenceController sharedPreferenceController];
    
    for (FUPlugInWrapper *wrap in [self plugInWrappers]) {
        [self setUpPrefPaneForPlugInWrapper:wrap];
    }
    
    for (FUPlugInWrapper *wrap in [self plugInWrappers]) {
        NSString *identifier = wrap.identifier;
        FUPlugInPreferences *client = (FUPlugInPreferences *)[[OAPreferenceController sharedPreferenceController] clientWithIdentifier:identifier];
        client.plugInWrapper = wrap;
        
        NSView *contentView = [client contentView];
        NSView *preferencesView = wrap.preferencesViewController.view;
        NSSize prefSize = [preferencesView bounds].size;
        
        if (prefSize.width < MIN_PREFS_VIEW_WIDTH) {
            prefSize.width = MIN_PREFS_VIEW_WIDTH;
        }
        NSView *controlBox = [client controlBox];
        NSSize boxSize = prefSize;
        boxSize.height += PREFS_VIEW_VERTICAL_FUDGE;
        [controlBox setFrameSize:boxSize];
        
        [contentView addSubview:preferencesView];
        
        [client updatePopUpMenu];
    }
}


- (void)setUpPrefPaneForPlugInWrapper:(FUPlugInWrapper *)wrap {
    NSString *identifier = wrap.identifier;
    NSString *title = wrap.localizedTitle;
    
    NSMutableDictionary *desc = [NSMutableDictionary dictionary];
#ifdef FAKE
    [desc setObject:@"Panels" forKey:@"category"];
#else
    [desc setObject:@"Plug-ins" forKey:@"category"];
#endif
    [desc setObject:@"nib" forKey:@"FUPlugInPreferences"];
    [desc setObject:[NSNumber numberWithInteger:1000] forKey:@"ordering"];
    
    [desc setObject:wrap.preferencesIconImageName forKey:@"icon"];
    [desc setObject:NSStringFromClass([wrap.plugIn class]) forKey:@"iconBundleClassName"];
    [desc setObject:identifier forKey:@"identifier"];
    [desc setObject:title forKey:@"shortTitle"];
    [desc setObject:[NSString stringWithFormat:NSLocalizedString(@"%@ Plug-in", @""), title] forKey:@"title"];

    // hardcode ordering for mulitple BrowsaBrowsa plugins. ensures they show up in prefpane in order we want. otherwise they get jumbled. :0[
    if ([identifier hasPrefix:@"com.fluidapp.BrowsaPlugIn"]) {
        NSInteger ordering = 0;
        if ([identifier isEqualToString:@"com.fluidapp.BrowsaPlugIn0"]) {
            ordering = 200;
        } else if ([identifier isEqualToString:@"com.fluidapp.BrowsaPlugIn1"]) {
            ordering = 210;
        } else if ([identifier isEqualToString:@"com.fluidapp.BrowsaPlugIn2"]) {
            ordering = 220;
        } else if ([identifier isEqualToString:@"com.fluidapp.BrowsaPlugIn3"]) {
            ordering = 230;
        } else if ([identifier isEqualToString:@"com.fluidapp.BrowsaPlugIn4"]) {
            ordering = 240;
        }
        [desc setObject:[NSNumber numberWithInteger:ordering] forKey:@"ordering"];
    }

    NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithDictionary:wrap.defaultsDictionary];
    [desc setObject:defaultsDictionary forKey:@"defaultsDictionary"];
    
    [OAPreferenceController registerItemName:@"FUPlugInPreferences" bundle:[NSBundle mainBundle] description:[[desc copy] autorelease]];
}


- (FUPlugInWrapper *)plugInWrapperForIdentifier:(NSString *)identifier {
    return [allPlugInWrappersTable objectForKey:identifier];
}


- (void)plugInMenuItemAction:(id)sender {
    FUPlugInWrapper *wrap = nil;
    NSString *identifier = nil;
    if ([sender isKindOfClass:[NSButton class]]) {
        identifier = [[sender cell] representedObject];
    } else {
        identifier = [sender representedObject];
    }
    wrap = [self plugInWrapperForIdentifier:identifier];
    
    FUPlugInViewPlacement mask = wrap.viewPlacementMask;
    
    NSWindow *window = nil;
    if (!FUPlugInViewPlacementIsPanel(mask)) {
        window = [[[FUDocumentController instance] frontWindowController] window];
    }

    for (FUPlugInWrapper *visibleWrap in [self visiblePlugInWrappers]) {
        if (visibleWrap != wrap && visibleWrap.viewPlacementMask == mask) {
            if ([visibleWrap isVisibleInWindowNumber:[window windowNumber]]) {
                [self toggleVisibilityOfPlugInWrapper:visibleWrap inWindow:window];
            }
        }
    }
    //[self hidePlugInWrapperWithViewPlacementMask:plugInWrapper.viewPlacementMask inWindow:window];
    [self toggleVisibilityOfPlugInWrapper:wrap inWindow:window];
}


- (void)plugInAboutMenuItemAction:(id)sender {
    NSString *identifier = [sender representedObject];
    FUPlugInWrapper *wrap = [self plugInWrapperForIdentifier:identifier];
    [NSApp orderFrontStandardAboutPanelWithOptions:wrap.aboutInfoDictionary];
}


- (void)toggleVisibilityOfPlugInWrapper:(FUPlugInWrapper *)wrap {
    NSUInteger mask = wrap.viewPlacementMask;
    if (FUPlugInViewPlacementIsPanel(mask)) {
        [self toggleVisibilityOfPlugInWrapper:wrap inWindow:nil];
    } else {
        NSArray *docs = [[FUDocumentController instance] documents];
        for (FUDocument *doc in docs) {
            [self toggleVisibilityOfPlugInWrapper:wrap inWindow:[[doc windowController] window]];
        }
    }
}


- (void)hidePlugInWrapperInAllWindows:(FUPlugInWrapper *)wrap {
    NSUInteger mask = wrap.viewPlacementMask;
    if (FUPlugInViewPlacementIsPanel(mask)) {
        if ([wrap isVisibleInWindowNumber:-1]) {
            [self toggleVisibilityOfPlugInWrapper:wrap inWindow:nil];
        }
    } else {
        NSArray *docs = [[FUDocumentController instance] documents];
        for (FUDocument *doc in docs) {
            NSWindow *win = [[doc windowController] window];
            if ([wrap isVisibleInWindowNumber:[win windowNumber]]) {
                [self toggleVisibilityOfPlugInWrapper:wrap inWindow:win];
            }
        }
    }
}


- (void)showPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    NSUInteger mask = wrap.viewPlacementMask;
    if (FUPlugInViewPlacementIsPanel(mask)) {
        if (![wrap isVisibleInWindowNumber:-1]) {
            [self toggleVisibilityOfPlugInWrapper:wrap inWindow:nil];
        }
    } else {
        [self hidePlugInWrapperWithViewPlacementMask:wrap.viewPlacementMask inWindow:win];

        if (![wrap isVisibleInWindowNumber:[win windowNumber]]) {
            [self toggleVisibilityOfPlugInWrapper:wrap inWindow:win];
        }
    }
}


- (NSArray *)visiblePlugInWrappers {
    NSArray *ids = [[FUUserDefaults instance] visiblePlugInIdentifiers];
    
    NSMutableArray *result = nil;

    if ([ids count]) {
        result = [NSMutableArray arrayWithCapacity:[ids count]];
        
        NSSet *visiblePlugIns = [NSSet setWithArray:ids];
        FUPlugInController *mgr = [FUPlugInController instance];
        if (visiblePlugIns.count) {
            for (NSString *identifier in visiblePlugIns) {
                FUPlugInWrapper *wrap = [mgr plugInWrapperForIdentifier:identifier];
                if (wrap) { // if a plugin has been removed, this could be nil causing crash
                    [result addObject:wrap];
                }
            }
        }    
    }
    
    return result;
}


- (void)hidePlugInWrapperWithViewPlacementMask:(FUPlugInViewPlacement)mask inWindow:(NSWindow *)win {
    for (FUPlugInWrapper *wrap in [self visiblePlugInWrappers]) {
        if (mask == wrap.viewPlacementMask) {
            if ([wrap isVisibleInWindowNumber:[win windowNumber]]) {
                [self toggleVisibilityOfPlugInWrapper:wrap inWindow:win];
            }
        }
    }
}


- (void)toggleVisibilityOfPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    NSInteger mask = wrap.viewPlacementMask;
    BOOL isPanelMask = FUPlugInViewPlacementIsPanel(mask);

    if (!isPanelMask && !win) {
        NSBeep();
        return;
    }
    
    switch (mask) {
        case FUPlugInViewPlacementUtilityPanel:
            [self toggleUtilityPanelPlugInWrapper:wrap];
            break;
        case FUPlugInViewPlacementFloatingUtilityPanel:
            [self toggleFloatingUtilityPanelPlugInWrapper:wrap];
            break;
        case FUPlugInViewPlacementHUDPanel:
            [self toggleHUDPanelPlugInWrapper:wrap];
            break;
        case FUPlugInViewPlacementFloatingHUDPanel:
            [self toggleFloatingHUDPanelPlugInWrapper:wrap];
            break;
        case FUPlugInViewPlacementSplitViewBottom:
            [self toggleSplitViewBottomPlugInWrapper:wrap inWindow:win];
            break;
        case FUPlugInViewPlacementSplitViewLeft:
            [self toggleSplitViewLeftPlugInWrapper:wrap inWindow:win];
            break;
        case FUPlugInViewPlacementSplitViewRight:
            [self toggleSplitViewRightPlugInWrapper:wrap inWindow:win];
            break;
        case FUPlugInViewPlacementSplitViewTop:
            [self toggleSplitViewTopPlugInWrapper:wrap inWindow:win];
            break;
        case FUPlugInViewPlacementDrawer:
            [self toggleDrawerPlugInWrapper:wrap inWindow:win];
            break;
        default:
            NSAssert(0, @"unknown view placement mask");
            break;
    }
}


- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize {
    [[FUUserDefaults instance] setPlugInDrawerContentSizeString:NSStringFromSize(contentSize)];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return contentSize;
}


- (void)toggleDrawerPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {    
    NSViewController *vc = [wrap plugInViewControllerForWindowNumber:[win windowNumber]];
    
    NSAssert([[win drawers] count], @"");
    NSDrawer *drawer = [[win drawers] objectAtIndex:0];
    
    if (![drawer delegate]) {
        [drawer setDelegate:self];        
    }

    if (NSDrawerOpeningState == [drawer state] || NSDrawerClosingState == [drawer state]) {
        NSBeep();
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:wrap selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:win];
    
    NSString *identifier = [wrap identifier];
    NSMutableSet *visiblePlugIns = [NSMutableSet setWithArray:[[FUUserDefaults instance] visiblePlugInIdentifiers]];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:drawer forKey:FUPlugInViewControllerDrawerKey];
    
    if (NSDrawerOpenState == [drawer state]) {
        [[drawer contentView] setNeedsDisplay:YES];

        [self post:FUPlugInViewControllerWillDisappearNotifcation forPlugInWrapper:wrap viewController:vc userInfo:userInfo];
        [drawer close:self];
        [wrap setVisible:NO inWindowNumber:[win windowNumber]];
        [self post:FUPlugInViewControllerDidDisappearNotifcation forPlugInWrapper:wrap viewController:vc userInfo:userInfo];
        [visiblePlugIns removeObject:identifier];
    } else {
        NSString *contentSizeString = [[FUUserDefaults instance] plugInDrawerContentSizeString];
        if ([contentSizeString length]) {
            [drawer setContentSize:NSSizeFromString(contentSizeString)];
        }
        [[drawer contentView] addSubview:vc.view];
        [vc.view setFrameSize:[drawer contentSize]];
        [[drawer contentView] setNeedsDisplay:YES];
        
        [self post:FUPlugInViewControllerWillAppearNotifcation forPlugInWrapper:wrap viewController:vc userInfo:userInfo];
        [drawer open:self];
        [wrap setVisible:YES inWindowNumber:[win windowNumber]];
        [self post:FUPlugInViewControllerDidAppearNotifcation forPlugInWrapper:wrap viewController:vc userInfo:userInfo];
        [visiblePlugIns addObject:identifier];
    }

    [[FUUserDefaults instance] setVisiblePlugInIdentifiers:[visiblePlugIns allObjects]];
}


- (void)toggleUtilityPanelPlugInWrapper:(FUPlugInWrapper *)wrap {
    [self togglePanelPluginWrapper:wrap isFloating:NO isHUD:NO];
}


- (void)toggleFloatingUtilityPanelPlugInWrapper:(FUPlugInWrapper *)wrap {
    [self togglePanelPluginWrapper:wrap isFloating:YES isHUD:NO];
}


- (void)toggleHUDPanelPlugInWrapper:(FUPlugInWrapper *)wrap {
    [self togglePanelPluginWrapper:wrap isFloating:NO isHUD:YES];    
}


- (void)toggleFloatingHUDPanelPlugInWrapper:(FUPlugInWrapper *)wrap {
    [self togglePanelPluginWrapper:wrap isFloating:YES isHUD:YES];    
}


- (void)togglePanelPluginWrapper:(FUPlugInWrapper *)wrap isFloating:(BOOL)isFloating isHUD:(BOOL)isHUD {
    NSString *identifier = wrap.identifier;
    NSViewController *vc = [wrap plugInViewControllerForWindowNumber:-1];
    NSView *plugInView = vc.view;

    NSPanel *panel = [windowsForPlugInIdentifier objectForKey:identifier];
    
    if (!panel) {
        panel = [self newPanelWithContentView:plugInView isHUD:isHUD];
        [panel setFloatingPanel:isFloating];
        [panel setReleasedWhenClosed:YES];
        
        [windowsForPlugInIdentifier setObject:panel forKey:wrap.identifier];
    }
    
    BOOL visible = [wrap isVisibleInWindowNumber:-1];
    
    if (visible) {
        [self post:FUPlugInViewControllerWillDisappearNotifcation forPlugInWrapper:wrap viewController:vc];
        
        [wrap setVisible:NO inWindowNumber:-1];
        [panel close];

        [self post:FUPlugInViewControllerDidDisappearNotifcation forPlugInWrapper:wrap viewController:vc];
    } else {

        [self post:FUPlugInViewControllerWillAppearNotifcation forPlugInWrapper:wrap viewController:vc];
        
        [wrap setVisible:YES inWindowNumber:-1];
        [panel setIsVisible:YES];
        [panel makeKeyAndOrderFront:self];
        
        [self post:FUPlugInViewControllerDidAppearNotifcation forPlugInWrapper:wrap viewController:vc];
    }
}


- (void)windowWillClose:(NSNotification *)n {
    NSWindow *window = [n object];
    if (![window isKindOfClass:[NSPanel class]]) {
        return;
    }
    
//    NSPanel *panel = (NSPanel *)window;
//    NSInteger windowNumber = [panel windowNumber];
    
    for (FUPlugInWrapper *wrap in [self plugInWrappers]) {
        NSViewController *vc = [wrap plugInViewControllerForWindowNumber:-1];
        if (vc) {
            if (![wrap isVisibleInWindowNumber:-1]) {
                continue;
            }
            [self toggleVisibilityOfPlugInWrapper:wrap];
            return;
        }
    }
}


- (NSPanel *)newPanelWithContentView:(NSView *)contentView isHUD:(BOOL)isHUD {
    NSRect contentRect = NSMakeRect(0, 0, 200, 300);
    NSInteger mask = (NSUtilityWindowMask|NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask);
    if (isHUD) {
        mask = (mask|NSHUDWindowMask);
    }
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:contentRect
                                                styleMask:mask
                                                  backing:NSBackingStoreBuffered
                                                    defer:YES];
    [panel setHasShadow:YES];
    [panel setReleasedWhenClosed:NO];
    [panel setHidesOnDeactivate:YES];
    [contentView setFrame:contentRect];
    [panel setContentView:contentView];
    [panel setBecomesKeyOnlyIfNeeded:YES];
    [panel setDelegate:self];
    
    FUWindowController *wc = [[FUDocumentController instance] frontWindowController];
    if (wc) {
        NSWindow *window = [wc window];
        NSRect frame = [window frame];
        NSPoint p = NSMakePoint(frame.origin.x + frame.size.width - 30,
                                frame.origin.y + frame.size.height - (40 + contentRect.size.height));
        [panel setFrameOrigin:p];
    } else {
        [panel center];
    }
    return panel;
}


- (void)toggleSplitViewTopPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    [self toggleSplitViewPluginWrapper:wrap isVertical:NO isFirst:YES inWindow:win];
}


- (void)toggleSplitViewBottomPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    [self toggleSplitViewPluginWrapper:wrap isVertical:NO isFirst:NO inWindow:win];
}


- (void)toggleSplitViewLeftPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    [self toggleSplitViewPluginWrapper:wrap isVertical:YES isFirst:YES inWindow:win];
}


- (void)toggleSplitViewRightPlugInWrapper:(FUPlugInWrapper *)wrap inWindow:(NSWindow *)win {
    [self toggleSplitViewPluginWrapper:wrap isVertical:YES isFirst:NO inWindow:win];
}


- (void)toggleSplitViewPluginWrapper:(FUPlugInWrapper *)wrap isVertical:(BOOL)isVertical isFirst:(BOOL)isFirst inWindow:(NSWindow *)win {
    FUWindowController *wc = [win windowController];
    
    NSViewController *vc = [wrap plugInViewControllerForWindowNumber:[win windowNumber]];
    NSView *plugInView = vc.view;
    
    [[NSNotificationCenter defaultCenter] addObserver:wrap
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:win];
    
    TDUberView *uberView = wc.uberView;
    
    NSString *identifier = wrap.identifier;
    NSMutableSet *visiblePlugIns = [NSMutableSet setWithArray:[[FUUserDefaults instance] visiblePlugInIdentifiers]];
    
    BOOL isLeft   = (isVertical && isFirst);
    BOOL isRight  = (isVertical && !isFirst);
    BOOL isTop    = (!isVertical && isFirst);
    BOOL isBottom = (!isVertical && !isFirst);
    
    BOOL isAppearing = NO;
    if      (isLeft)   isAppearing = !uberView.isLeftViewOpen;
    else if (isRight)  isAppearing = !uberView.isRightViewOpen;
    else if (isTop)    isAppearing = !uberView.isTopViewOpen;
    else if (isBottom) isAppearing = !uberView.isBottomViewOpen;
    
    NSString *name = isAppearing ? FUPlugInViewControllerWillAppearNotifcation : FUPlugInViewControllerWillDisappearNotifcation;
    [self post:name forPlugInWrapper:wrap viewController:vc];
    [wrap setVisible:isAppearing inWindowNumber:[win windowNumber]];
    
    if (isLeft)    {
        uberView.preferredLeftSplitWidth = wrap.preferredVerticalSplitPosition;
        uberView.leftView = isAppearing ? plugInView : nil;
        [uberView toggleLeftView:wrap];
    } else if (isRight) {
        uberView.preferredRightSplitWidth = wrap.preferredVerticalSplitPosition;
        uberView.rightView = isAppearing ? plugInView : nil;
        [uberView toggleRightView:wrap];
    } else if (isTop) {
        uberView.preferredTopSplitHeight = wrap.preferredHorizontalSplitPosition;
        uberView.topView = isAppearing ? plugInView : nil;
        [uberView toggleTopView:wrap];
    } else if (isBottom) {
        uberView.preferredBottomSplitHeight = wrap.preferredHorizontalSplitPosition;
        uberView.bottomView = isAppearing ? plugInView : nil;
        [uberView toggleBottomView:wrap];
    }

    name = isAppearing ? FUPlugInViewControllerDidAppearNotifcation : FUPlugInViewControllerDidDisappearNotifcation;
    [self post:name forPlugInWrapper:wrap viewController:vc];
    
    if (isAppearing) {
        [visiblePlugIns addObject:identifier];
    } else {
        [visiblePlugIns removeObject:identifier];
    }

    [[FUUserDefaults instance] setVisiblePlugInIdentifiers:[visiblePlugIns allObjects]];
}


- (void)post:(NSString *)name forPlugInWrapper:(FUPlugInWrapper *)wrap viewController:(NSViewController *)vc {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [self post:name forPlugInWrapper:wrap viewController:vc userInfo:userInfo];
}


- (void)post:(NSString *)name forPlugInWrapper:(FUPlugInWrapper *)wrap viewController:(NSViewController *)vc userInfo:(NSMutableDictionary *)userInfo {
    [userInfo setObject:wrap.plugIn forKey:FUPlugInKey];
    [userInfo setObject:vc forKey:FUPlugInViewControllerKey];
    [userInfo setObject:[NSNumber numberWithInteger:wrap.viewPlacementMask] forKey:FUPlugInViewPlacementMaskKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:name object:vc userInfo:[[userInfo copy] autorelease]];
}


#pragma mark -
#pragma mark Properties

NSInteger FUPlugInWrapperSort(id a, id b, void *ctx) {
    NSInteger sortA = [a sortOrder];
    NSInteger sortB = [b sortOrder];
    
    if (sortA < sortB) {
        return NSOrderedAscending;
    } else if (sortB < sortA) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}


NSInteger FUPlugInIdentifierSort(id a, id b, void *ctx) {
    NSInteger sortA = [[[FUPlugInController instance] plugInWrapperForIdentifier:a] sortOrder];
    NSInteger sortB = [[[FUPlugInController instance] plugInWrapperForIdentifier:b] sortOrder];
    
    if (sortA < sortB) {
        return NSOrderedAscending;
    } else if (sortB < sortA) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}


- (NSArray *)plugInWrappers {
    NSMutableArray *ma = [NSMutableArray arrayWithArray:[allPlugInWrappersTable allValues]];
    [ma sortUsingFunction:FUPlugInWrapperSort context:NULL];
    return [[ma copy] autorelease];
}


- (NSArray *)allPlugInIdentifiers {
    NSMutableArray *ma = [NSMutableArray arrayWithArray:[allPlugInWrappersTable allKeys]];
    [ma sortUsingFunction:FUPlugInIdentifierSort context:NULL];
    return [[ma copy] autorelease];
}

@synthesize plugInMenu;
@synthesize windowsForPlugInIdentifier;
@synthesize plugInAPI;
@synthesize allPlugInWrappersTable;
@end
