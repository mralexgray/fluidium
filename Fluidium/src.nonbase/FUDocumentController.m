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

#import "FUDocumentController.h"
#import "FUDocument.h"
#import "FUWindowController.h"
#import "FUTabController.h"
#import "FUUserDefaults.h"
#import "FUWebView.h"
#import "FUJavaScriptBridge.h"
#import "FUJavaScriptMenuItem.h"
#import "FUNotifications.h"
#import "FUDownloadWindowController.h"

#import <WebKit/WebKit.h>
#import <Growl/Growl.h>
#import <Sparkle/Sparkle.h>

#define OPEN_NEW_TAB 0

@interface FUDocumentController ()
- (void)registerForAppleEventHandling;
- (void)unregisterForAppleEventHandling;
- (void)handleInternetOpenContentsEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleOpenContentsAppleEventWithURL:(NSString *)URLString;

- (void)restoreSession;
- (void)checkForUpdates;
@end

@implementation FUDocumentController

+ (FUDocumentController *)instance {
    return (id)[[NSApplication sharedApplication] delegate];
}


- (id)init {
    if (self = [super init]) {
        [GrowlApplicationBridge setGrowlDelegate:(NSObject <GrowlApplicationBridgeDelegate>*)self];
    }
    return self;
}


- (void)dealloc {
    self.hiddenWindow = nil;
    [super dealloc];
}


- (NSString *)defaultType {
    return @"Web archive";
}


#pragma mark -
#pragma mark Action

- (IBAction)toggleTabBarShown:(id)sender {
    BOOL hidden = ![[FUUserDefaults instance] tabBarHiddenAlways];
    [[FUUserDefaults instance] setTabBarHiddenAlways:hidden];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUTabBarShownDidChangeNotification object:nil];
}


- (IBAction)toggleBookmarkBarShown:(id)sender {
    BOOL shown = ![[FUUserDefaults instance] bookmarkBarShown];
    [[FUUserDefaults instance] setBookmarkBarShown:shown];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUBookmarkBarShownDidChangeNotification object:nil];
}


- (IBAction)toggleStatusBarShown:(id)sender {
    BOOL shown = ![[FUUserDefaults instance] statusBarShown];
    [[FUUserDefaults instance] setStatusBarShown:shown];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUStatusBarShownDidChangeNotification object:nil];
}


// support for opening a new window on ⌘-L when there are no existing windows
- (IBAction)openLocation:(id)sender {
    [self newDocument:sender];
}


// support for opening a new window on ⌘⎇-F when there are no existing windows
- (IBAction)openSearch:(id)sender {
    FUDocument *doc = [self openUntitledDocumentAndDisplay:YES error:nil];
    if (doc) {
        [[doc windowController] openSearch:sender];
    }
}


// support for opening a new window on ⌘-T when there are no existing windows
- (IBAction)newTab:(id)sender {
    [self newDocument:sender];
}


- (IBAction)newBackgroundTab:(id)sender {
    [self newDocument:sender];
}


// support for user JavaScript dock menu item callbacks
- (IBAction)dockMenuItemClick:(id)sender {
    FUTabController *tc = [self frontTabController];
    if (tc) {
        FUJavaScriptMenuItem *jsItem = [sender representedObject];        
        [tc.javaScriptBridge dockMenuItemClick:jsItem];
    }
}


#pragma mark -
#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)n {
    [self registerForAppleEventHandling];
	// Mital Vora.
	// Do not restore session as not to navigate and / or open multiple tabs at all.
    //[self restoreSession];
    [self checkForUpdates];
}


- (void)applicationWillTerminate:(NSNotification *)n {
    // is this necessary?
    [self unregisterForAppleEventHandling];
    [self saveSession];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
	return YES;
}


- (void)applicationDidBecomeActive:(NSNotification *)n {
    if (hiddenWindow) {
        [hiddenWindow makeKeyAndOrderFront:self];
    }
}

- (id)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError **)outError {
    if (hiddenWindow) {
        [hiddenWindow makeKeyAndOrderFront:self];
		NSWindow *orig_hiddenWindow = hiddenWindow;
		hiddenWindow = nil;
		return orig_hiddenWindow;
    }
	return [super openUntitledDocumentAndDisplay:displayDocument error:outError];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)app {
    NSArray *jsItems = [[[self frontTabController] javaScriptBridge] dockMenuItems];
    if (![jsItems count]) return nil;
        
    NSMenu *menu = [[[NSMenu alloc] init] autorelease];
    
    for (FUJavaScriptMenuItem *jsItem in jsItems) {
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:jsItem.title
                                                           action:@selector(dockMenuItemClick:)
                                                    keyEquivalent:@""] autorelease];
        [menuItem setTarget:self];
        [menuItem setRepresentedObject:jsItem];
        [menu addItem:menuItem];
    }
    
    return menu;
}


#pragma mark -
#pragma mark NSMenuDelegate

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL action = [item action];
    
    if (@selector(toggleTabBarShown:) == action) {
        BOOL hideAlways = [[FUUserDefaults instance] tabBarHiddenAlways];
        [item setTitle:hideAlways ? NSLocalizedString(@"Show Tab Bar", @"") : NSLocalizedString(@"Hide Tab Bar", @"")];
        
        BOOL tabbedBrowsingEnabled = [[FUUserDefaults instance] tabbedBrowsingEnabled];
        if (!tabbedBrowsingEnabled) {
            return NO;
        }
        
        BOOL onlyOneTab = (1 == [[[self frontWindowController] tabControllers] count]);
        if (onlyOneTab) {
            BOOL hideForSingleTab = [[FUUserDefaults instance] tabBarHiddenForSingleTab];
            return !hideForSingleTab;
        } else {
            return tabbedBrowsingEnabled;
        }

    } else if (@selector(toggleBookmarkBarShown:) == action) {
        BOOL shown = [[FUUserDefaults instance] bookmarkBarShown];
        [item setTitle:shown ? NSLocalizedString(@"Hide Bookmark Bar", @"") : NSLocalizedString(@"Show Bookmark Bar", @"")];
        return YES;
        
    } else if (@selector(toggleStatusBarShown:) == action) {
        BOOL shown = [[FUUserDefaults instance] statusBarShown];
        [item setTitle:shown ? NSLocalizedString(@"Hide Status Bar", @"") : NSLocalizedString(@"Show Status Bar", @"")];
        return YES;
    } else {
        return YES;
    }
}


#pragma mark -
#pragma mark GrowBridgeDelegate

- (void)growlNotificationWasClicked:(id)clickContext {
    
}


#pragma mark -
#pragma mark Public

- (FUDocument *)openDocumentWithURL:(NSString *)s makeKey:(BOOL)makeKey; {
    FUDocument *oldDoc = [self frontDocument];
    FUDocument *newDoc = [self openUntitledDocumentAndDisplay:makeKey error:nil];
    
    if (!makeKey) {
        [newDoc makeWindowControllers];
    }
    
    if (!makeKey) {
        NSWindow *oldWin = [[oldDoc windowController] window];
        NSWindow *newWin = [[newDoc windowController] window];
        [newWin orderWindow:NSWindowBelow relativeTo:[oldWin windowNumber]];
        
    }
    
    if ([s length]) {
        FUTabController *tc = [[newDoc windowController] selectedTabController];
        [tc loadURL:s];
    }
    
    return newDoc;
}


- (FUTabController *)loadURL:(NSString *)s {
    return [self loadURL:s destinationType:[[FUUserDefaults instance] tabbedBrowsingEnabled] ? FUDestinationTypeTab : FUDestinationTypeWindow];
}


- (FUTabController *)loadURL:(NSString *)s destinationType:(FUDestinationType)type {
    return [self loadURL:s destinationType:type inForeground:[[FUUserDefaults instance] selectNewWindowsOrTabsAsCreated]];
}


- (FUTabController *)loadURL:(NSString *)s destinationType:(FUDestinationType)type inForeground:(BOOL)inForeground {
    FUTabController *tc = nil;
    if (![[self documents] count] || FUDestinationTypeWindow == type) {
        FUDocument *doc = [self openDocumentWithURL:s makeKey:inForeground];
        tc = [[doc windowController] selectedTabController];
    } else {
        FUWindowController *wc = [self frontWindowController];
        tc = [wc loadURL:s inNewTabAndSelect:inForeground];
        [[wc window] makeKeyAndOrderFront:self]; // this is necessary if opening in a tab, and an auxilliary window is key
    }
    return tc;
}


- (void)downloadRequest:(NSURLRequest *)req directory:(NSString *)dirPath filename:(NSString *)filename {
    [[FUDownloadWindowController instance] downloadRequest:req directory:dirPath filename:filename];
}


- (WebFrame *)findFrameNamed:(NSString *)name outTabController:(FUTabController **)outTabController {
    // look for existing frame in any open browser document with this name.
    WebFrame *existingFrame = nil;
    
    for (FUDocument *doc in [self documents]) {
        for (FUTabController *tc in [[doc windowController] tabControllers]) {
            existingFrame = [[[tc webView] mainFrame] findFrameNamed:name];
            if (existingFrame) {
                if (outTabController) {
                    *outTabController = tc;
                }
                break;
            }
        }
    }
    
    return existingFrame;
}


- (FUDocument *)frontDocument {
    // despite what the docs say, -currentDocument does not return a document if it is main but not key. dont trust it. :(
    //return (FUDocument *)[self currentDocument];

    for (NSWindow *win in [NSApp orderedWindows]) {
        NSDocument *doc = [self documentForWindow:win];
        if (doc && [doc isKindOfClass:[FUDocument class]]) {
            return (FUDocument *)doc;
        }
    }
    return nil;
}


- (FUWindowController *)frontWindowController {
    return [[self frontDocument] windowController];
}


- (FUTabController *)frontTabController {
    return [[self frontWindowController] selectedTabController];
}


- (WebView *)frontWebView {
    return [[self frontTabController] webView];
}


#pragma mark -
#pragma mark Private

- (void)registerForAppleEventHandling {
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(handleInternetOpenContentsEvent:replyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
}


- (void)unregisterForAppleEventHandling {
    [[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
}


- (void)handleInternetOpenContentsEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *URLString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    [self handleOpenContentsAppleEventWithURL:URLString];
}


- (void)handleOpenContentsAppleEventWithURL:(NSString *)URLString {
    FUDestinationType type = FUDestinationTypeWindow;

    FUWindowController *wc = [self frontWindowController];
    if (wc) {
        NSWindow *window = [wc window];
        if ([window isMiniaturized]) {
            [window deminiaturize:self];
        }

        if ([[FUUserDefaults instance] tabbedBrowsingEnabled]) {
            type = [[FUUserDefaults instance] openLinksFromApplicationsIn];
        }
    }

    [self loadURL:URLString destinationType:type inForeground:YES];
}


- (void)saveSession {
    if (![[FUUserDefaults instance] sessionsEnabled]) return;
    
    NSArray *docs = [self documents];
    NSMutableArray *wins = [NSMutableArray arrayWithCapacity:[docs count]];
    
    for (FUDocument *doc in docs) {
        FUWindowController *wc = [doc windowController];
        NSArray *tabItems = [wc.tabView tabViewItems];
        NSMutableArray *tabs = [NSMutableArray arrayWithCapacity:[tabItems count]];
        
        for (NSTabViewItem *tabItem in tabItems) {
            [tabs addObject:[[tabItem identifier] URLString]];
        }
        
        NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithInteger:wc.selectedTabIndex], @"selectedTabIndex",
                           tabs, @"tabs",
                           nil];
        
        [wins addObject:d];
    }
    
    [[FUUserDefaults instance] setSessionInfo:wins];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)restoreSession {
    if (![[FUUserDefaults instance] sessionsEnabled]) return;

    NSArray *wins = [[FUUserDefaults instance] sessionInfo];
    NSInteger i = 0;
    for (NSDictionary *d in wins) {
        FUDocument *doc = nil;
        
        if (0 == i++ && [[self documents] count]) {
            doc = [[self documents] objectAtIndex:0];
        } else {
            doc = [self openUntitledDocumentAndDisplay:YES error:nil];
        }
        
        FUWindowController *wc = doc.windowController;
        NSArray *tabs = [d objectForKey:@"tabs"];
        
        for (NSString *URLString in tabs) {
            [wc loadURL:URLString inNewTabAndSelect:YES];
        }
        
        wc.selectedTabIndex = [[d objectForKey:@"selectedTabIndex"] integerValue];
    }
}


- (void)checkForUpdates {
    SUUpdater *updater = [SUUpdater sharedUpdater];
    if ([updater automaticallyChecksForUpdates]) {
        [updater checkForUpdatesInBackground];
    }
}

@synthesize hiddenWindow; // weak ref
@end
