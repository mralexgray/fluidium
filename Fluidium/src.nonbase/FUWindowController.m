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

#import "FUWindowController.h"
#import "FUWindowController+NSToolbarDelegate.h"
#import "FUDocumentController.h"
#import "FUTabController.h"
#import "FUWindow.h"
#import "FUUserDefaults.h"
#import "FUProgressComboBox.h"
#import "FURecentURLController.h"
#import "FUViewSourceWindowController.h"
#import "FUShortcutController.h"
#import "FUShortcutCommand.h"
#import "FUBookmarkController.h"
#import "FUBookmark.h"
#import "FUActivation.h"
#import "FUUtils.h"
#import "FUWebView.h"
#import "FUTabBarControl.h"
#import "FUWindowToolbar.h"
#import "FUPlugInController.h"
#import "FUPlugInWrapper.h"
#import "FUNotifications.h"
#import "NSString+FUAdditions.h"
#import "WebURLsWithTitles.h"
#import "WebViewPrivate.h"
#import <WebKit/WebKit.h>
#import <PSMTabBarControl/PSMTabBarControl.h>
#import <TDAppKit/TDUberView.h>
#import <TDAppKit/TDLine.h>
#import <TDAppKit/TDComboField.h>
#import <TDAppKit/NSEvent+TDAdditions.h>

#define MIN_COMBOBOX_WIDTH 60
#define TOOLBAR_HEIGHT 36

@interface NSObject (FUAdditions)
- (void)noop:(id)sender;
@end

@interface FUTabController ()
@property (nonatomic, assign, readwrite) FUWindowController *windowController;
@end

@interface FUWindowController (FUTabBarDragging) // Don't use this method for anything else
- (void)tabControllerWasDroppedOnTabBar:(FUTabController *)tc;
@end

@interface FUWindowController ()
- (void)setUpTabBar;
- (void)closeWindow;
- (void)closeTab;
- (BOOL)removeTabViewItem:(NSTabViewItem *)tabItem;
- (void)tabControllerWasRemovedFromTabBar:(FUTabController *)tc;
- (void)saveFrameString;
- (void)startObservingTabController:(FUTabController *)tc;
- (void)stopObservingTabController:(FUTabController *)tc;
- (NSTabViewItem *)tabViewItemForTabController:(FUTabController *)tc;

- (NSInteger)preferredIndexForNewTab;

- (FUTabController *)tabControllerForCommandClick:(FUActivation *)act;
- (void)handleCommandClick:(FUActivation *)act URL:(NSString *)s;

- (BOOL)isToolbarVisible;
- (void)showToolbarTemporarilyIfHidden;
- (void)showToolbarTemporarily;
- (void)removeDocumentIconButton;
- (void)displayEstimatedProgress;
- (void)clearProgressInFuture;
- (void)clearProgress;

- (NSArray *)recentURLs;
- (NSArray *)matchingRecentURLs;
- (void)addRecentURL:(NSString *)s;
- (void)addMatchingRecentURL:(NSString *)s;

- (void)editBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(FUBookmark *)bmark;

- (void)toggleFindPanel:(BOOL)show;
- (BOOL)findPanelSearchField:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;
- (void)updateEmptyTabBarLineVisibility;
- (void)updateUberViewHeight;
- (void)updateContentViewFrame;

@property (nonatomic, retain, readwrite) FUTabController *selectedTabController;
@end

@implementation FUWindowController

- (id)init {
    return [self initWithWindowNibName:@"FUWindow"];
}


- (id)initWithWindowNibName:(NSString *)name {
    if (self = [super initWithWindowNibName:name]) {
        self.tabControllers = [NSMutableSet set];
        self.shortcutController = [[[FUShortcutController alloc] init] autorelease];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    for (FUTabController *tc in tabControllers) {
        [self stopObservingTabController:tc];
    }

    self.locationSplitView = nil;
    self.locationComboBox = nil;
    self.searchField = nil;
    self.tabContainerView = nil;
    self.tabBar = nil;
    self.emptyTabBarLine = nil;
    self.bookmarkBar = nil;
    self.uberView = nil;
    self.statusBar = nil;
    self.statusTextField = nil;
    self.statusProgressIndicator = nil;
    self.findPanelView = nil;
    self.findPanelSearchField = nil;
    self.editBookmarkSheet = nil;
    self.editingBookmark;
    self.tabView = nil;
    self.departingTabController = nil;
    self.viewSourceController = nil;
    self.shortcutController = nil;
    self.tabControllers = nil;
    self.selectedTabController = nil;
    self.currentTitle = nil;
    self.findPanelTerm = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p %@>", NSStringFromClass([self class]), self, [[self selectedTabController] URLString]];
}


- (void)awakeFromNib {    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(comboBoxWillDismiss:)
               name:NSComboBoxWillDismissNotification
             object:locationComboBox];
    
    [nc addObserver:self
           selector:@selector(controlTextDidChange:)
               name:NSControlTextDidChangeNotification
             object:locationComboBox];    
    
    [nc addObserver:self
           selector:@selector(controlTextDidBeginEditing:)
               name:NSControlTextDidBeginEditingNotification
             object:locationComboBox];
    
    [nc addObserver:self
           selector:@selector(toolbarShownDidChange:)
               name:FUToolbarShownDidChangeNotification
             object:[self window]];
    
    [nc addObserver:self
           selector:@selector(bookmarkBarShownDidChange:)
               name:FUBookmarkBarShownDidChangeNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(tabBarShownDidChange:)
               name:FUTabBarShownDidChangeNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(tabBarHiddenForSingleTabDidChange:)
               name:FUTabBarHiddenForSingleTabDidChangeNotification
             object:nil];    
    
    [nc addObserver:self
           selector:@selector(statusBarShownDidChange:)
               name:FUStatusBarShownDidChangeNotification
             object:nil];
}


- (void)windowDidLoad {
	// Mital Vora: disabling toolbar.
    // [self setUpToolbar];
    [self setUpTabBar];
    [self toolbarShownDidChange:nil];
    [self bookmarkBarShownDidChange:nil];
    [self statusBarShownDidChange:nil];
    [self tabBarShownDidChange:nil];

    [[self window] setFrameFromString:[[FUUserDefaults instance] windowFrameString]];
    
    [self addNewTabAndSelect:YES];

    if ([[FUUserDefaults instance] newWindowsOpenWith]) {
        [self webGoHome:self];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUWindowControllerDidOpenNotification object:self];
}


- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    return [[self selectedTabController] title];    
}


#pragma mark -
#pragma mark Actions

- (IBAction)webGoBack:(id)sender {
    [[self selectedTabController] webGoBack:sender];
}


- (IBAction)webGoForward:(id)sender {
    [[self selectedTabController] webGoForward:sender];
}


- (IBAction)webReload:(id)sender {
    [[self selectedTabController] webReload:sender];
}


- (IBAction)webStopLoading:(id)sender {
    [[self selectedTabController] webStopLoading:sender];
}


- (IBAction)webGoHome:(id)sender {
    [[self selectedTabController] webGoHome:sender];
}


- (IBAction)zoomIn:(id)sender {
    [[self selectedTabController] zoomIn:sender];
}


- (IBAction)zoomOut:(id)sender {
    [[self selectedTabController] zoomOut:sender];
}


- (IBAction)actualSize:(id)sender {
    [[self selectedTabController] actualSize:sender];
}


- (IBAction)goToLocation:(id)sender {
    NSMutableString *ms = [[[locationComboBox stringValue] mutableCopy] autorelease];
    CFStringTrimWhitespace((CFMutableStringRef)ms);
    
    if (![ms length]) {
        return;
    }
    
    NSString *s = [[ms copy] autorelease];
    FUShortcutCommand *cmd = [shortcutController commandForInput:s];
    
    if (cmd) {
        s = cmd.firstURLString;
    }
    
    [[self selectedTabController] loadURL:s];

    if (cmd.isTabbed) {
        for (NSString *URLString in cmd.moreURLStrings) {
            [self loadURL:[NSURLRequest requestWithURL:[NSURL URLWithString:URLString]] inNewTabAndSelect:NO];
        }
    }
}


- (IBAction)openSearch:(id)sender {
    [self showToolbarTemporarilyIfHidden];
    [[self window] performSelector:@selector(makeFirstResponder:) withObject:searchField afterDelay:0.1];
}


- (IBAction)search:(id)sender {
    if (![[searchField stringValue] length]) {
        return;
    }
    
    NSMutableString *q = [[[searchField stringValue] mutableCopy] autorelease];
    CFStringTrimWhitespace((CFMutableStringRef)q);
    NSString *URLString = [NSString stringWithFormat:FUDefaultWebSearchFormatString(), [q stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
    FUActivation *act = [FUActivation activationFromEvent:[[self window] currentEvent]];
    
    FUTabController *tc = nil;
    if (act.isCommandKeyPressed) {
        tc = [self tabControllerForCommandClick:act];
    } else {
        tc = [self selectedTabController];
    }
    [tc loadURL:URLString];
}


- (IBAction)openLocation:(id)sender {
    [self showToolbarTemporarilyIfHidden];
    [[self window] performSelector:@selector(makeFirstResponder:) withObject:locationComboBox afterDelay:0.1];
}


- (IBAction)viewSource:(id)sender {
    if (!viewSourceController) {
        self.viewSourceController = [[[FUViewSourceWindowController alloc] init] autorelease];
    }
    
    NSString *sourceString = [[self selectedTabController] documentSource];
    [viewSourceController displaySourceString:sourceString];
    
    [[self document] addWindowController:viewSourceController];
    [[viewSourceController window] makeKeyAndOrderFront:self];
    viewSourceController.URLString = [[self selectedTabController] URLString];
}


- (IBAction)emptyCache:(id)sender {
    NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Are you sure you want to empty the cache?", @""),
                                       @"",
                                       NSLocalizedString(@"Empty", @""),
                                       NSLocalizedString(@"Cancel", @""),
                                       nil);
    if (NSAlertDefaultReturn == result) {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    }
}


- (IBAction)toggleToolbarShown:(id)sender {
    [[self window] toggleToolbarShown:sender];
}


- (IBAction)newTab:(id)sender {
//    if (![self isToolbarVisible]) {
//        [self showToolbarTemporarily];
//        [self performSelector:@selector(newTab:) withObject:sender afterDelay:0.1];
//        return;
//    }
    
    [self addNewTabAndSelect:YES];
}


- (IBAction)newBackgroundTab:(id)sender {
    [self addNewTabAndSelect:NO];
}


- (IBAction)closeWindow:(id)sender {
    [self closeWindow];
}


- (IBAction)closeTab:(id)sender {
    if (1 == [tabView numberOfTabViewItems]) {
        [self closeWindow];
    } else {
        [self closeTab];
    }
}


- (IBAction)performClose:(id)sender {
    [self closeTab:sender];
}


// overridden in (Scripting) category to send close events for background tabs thru the scripting architecture for recording
- (IBAction)takeTabIndexToCloseFrom:(id)sender {
    [self removeTabControllerAtIndex:[sender tag]];
}


- (IBAction)takeTabIndexToReloadFrom:(id)sender {
    FUTabController *tc = [self tabControllerAtIndex:[sender tag]];
    [tc webReload:sender];
}


- (IBAction)takeTabIndexToMoveToNewWindowFrom:(id)sender {
    FUTabController *tc = [self tabControllerAtIndex:[sender tag]];
    
    NSError *err = nil;
    FUWindowController *newwc = [[[FUDocumentController instance] openUntitledDocumentAndDisplay:YES error:&err] windowController];
    
    if (newwc) {
        [self removeTabController:tc];
        FUTabController *oldtc = [newwc selectedTabController];
        [newwc addTabController:tc];
        [newwc removeTabController:oldtc];
    } else {
        NSLog(@"%@", err);
    }
}


- (IBAction)selectNextTab:(id)sender {
    NSInteger c = [tabView numberOfTabViewItems];
    NSUInteger i = self.selectedTabIndex + 1;
    
    i = (i % c);
    
    self.selectedTabIndex = i;
}


- (IBAction)selectPreviousTab:(id)sender {
    NSInteger c = [tabView numberOfTabViewItems];
    NSUInteger i = self.selectedTabIndex - 1;
    
    i = (i == -1) ? c - 1 : i;
    
    self.selectedTabIndex = i;
}


- (IBAction)hideFindPanel:(id)sender {
    if ([self isFindPanelVisible]) {
        [self toggleFindPanel:NO];
    }
}


- (IBAction)showFindPanel:(id)sender {
    if (![self isFindPanelVisible]) {
        [self toggleFindPanel:YES];
    }

    [[self window] makeFirstResponder:findPanelSearchField];
}


- (IBAction)find:(id)sender {
    WebView *wv = [[self selectedTabController] webView];
    if ([wv canMarkAllTextMatches]) {
        [wv unmarkAllTextMatches];
        [wv markAllMatchesForText:findPanelTerm caseSensitive:NO highlight:YES limit:0];
    }
    BOOL forward = (NSFindPanelActionNext == [sender tag]);
    BOOL found = [wv searchFor:findPanelTerm direction:forward caseSensitive:NO wrap:YES];
    
    if (!found && [findPanelTerm length]) {
        NSBeep();
    }
}


- (IBAction)useSelectionForFind:(id)sender {
    self.findPanelTerm = [[[[self selectedTabController] webView] selectedDOMRange] toString];
    [self find:sender];
}


- (IBAction)jumpToSelection:(id)sender {
    DOMElement *el = (DOMElement *)[[[[self selectedTabController] webView] selectedDOMRange] commonAncestorContainer];
    [el scrollIntoView:YES];
}


- (IBAction)addBookmark:(id)sender {
    NSString *URLString = [[self selectedTabController] URLString];
    if (![URLString length]) {
        NSBeep();
        return;
    }
    
    NSString *title = [[self selectedTabController] title];
    if (![title length]) {
        title = [URLString stringByTrimmingURLSchemePrefix];
    }
    
    FUBookmark *bmark = [FUBookmark bookmarkWithTitle:title content:URLString];
    
    [[FUBookmarkController instance] appendBookmark:bmark];
    
    [self runEditTitleSheetForBookmark:bmark];
}


- (IBAction)bookmarkClicked:(id)sender {
    FUBookmark *bmark = nil;
    if (sender && [sender isKindOfClass:[NSMenuItem class]]) {
        bmark = [sender representedObject];
    } else if ([sender isMemberOfClass:[FUBookmark class]]) {
        bmark = sender;
    } else {
        return;
    }
    
    NSString *URLString = [bmark.content stringByEnsuringURLSchemePrefix];    
    
    if ([bmark.content hasJavaScriptSchemePrefix]) {
        NSString *script = [bmark.content stringByTrimmingURLSchemePrefix];
        script = [script stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [[[self selectedTabController] webView] stringByEvaluatingJavaScriptFromString:script];
    } else {
        FUActivation *act = [FUActivation activationFromEvent:[[self window] currentEvent]];
        
        FUTabController *tc = nil;
        if (act.isCommandKeyPressed) {
            tc = [self tabControllerForCommandClick:act];
        } else {
            tc = [self selectedTabController];
        }
        [tc loadURL:URLString];
    }
}


- (IBAction)endEditBookmark:(id)sender {
    [NSApp endSheet:editBookmarkSheet returnCode:[sender tag]];
    [editBookmarkSheet orderOut:sender];
}


- (IBAction)showWebInspector:(id)sender {
    [[self selectedTabController] showWebInspector:sender];
}


- (IBAction)showErrorConsole:(id)sender {
    [[self selectedTabController] showErrorConsole:sender];
}


#pragma mark -
#pragma mark Public

- (void)runEditTitleSheetForBookmark:(FUBookmark *)bmark {
    self.editingBookmark = [FUBookmark bookmarkWithTitle:bmark.title content:bmark.content];
    
    [bmark retain]; // retained
    
    [NSApp beginSheet:editBookmarkSheet 
       modalForWindow:[self window] 
        modalDelegate:self 
       didEndSelector:@selector(editBookmarkSheetDidEnd:returnCode:contextInfo:) 
          contextInfo:bmark];
}


- (BOOL)isFindPanelVisible {
    return (nil != [findPanelView superview]);
}


- (FUTabController *)loadURLInSelectedTab:(NSString *)s {
    NSInteger i = self.selectedTabIndex;
    return [self loadURL:s inNewTab:NO atIndex:i andSelect:NO];
}


- (FUTabController *)loadURL:(NSString *)s inNewTabAndSelect:(BOOL)select {
    return [self loadURL:s inNewTab:YES atIndex:[self preferredIndexForNewTab] andSelect:select];
}


- (FUTabController *)loadURL:(NSString *)s inNewTab:(BOOL)shouldCreate atIndex:(NSInteger)i andSelect:(BOOL)select {
    FUTabController *tc = nil;

    // use selected tab if empty
    if (shouldCreate && ![[[self selectedTabController] URLString] length]) {
        shouldCreate = NO;
    }
        
    if (shouldCreate) {
        tc = [self insertNewTabAtIndex:i andSelect:select];
    } else {
        tc = [self tabControllerAtIndex:i];
        if (!tc) {
            tc = [self selectedTabController];
        }
        if (select) {
            [self selectTabController:tc];
        }
    }
    
    [tc loadURL:s];
    
    return tc;
}


- (FUTabController *)addNewTabAndSelect:(BOOL)select {
    NSInteger i = [self preferredIndexForNewTab];
    return [self insertNewTabAtIndex:i andSelect:select];
}


- (FUTabController *)insertNewTabAtIndex:(NSInteger)i andSelect:(BOOL)select {
    FUTabController *tc = [[[FUTabController alloc] initWithWindowController:self] autorelease];
    [self insertTabController:tc atIndex:i];
	// Mital Vora: navigate to home page.
	[tc webGoHome];
    if (select) {
        if ([self selectedTabController] != tc) {
            [self selectTabController:tc]; // !! this is doing nothing currently, cuz NSTabView auto selects added tabs (line above)
        }
		[[self window] makeFirstResponder:locationComboBox];
    }
    return tc;
}


- (void)addTabController:(FUTabController *)tc {
    [self insertTabController:tc atIndex:[self preferredIndexForNewTab]];
}


- (void)insertTabController:(FUTabController *)tc atIndex:(NSInteger)i {
    NSParameterAssert(tc);
    NSParameterAssert(i > -1);
    if ([tabControllers containsObject:tc]) {
        return;
    }

    tc.windowController = self;
    
    NSInteger c = [tabControllers count];
    i = i > c ? c : i;
    
    [tabControllers addObject:tc];
    
    NSTabViewItem *tabItem = [[[NSTabViewItem alloc] initWithIdentifier:tc] autorelease];
    [tc.view setFrame:[uberView.midView bounds]]; // need to set the frame here to make sure it is valid for any thumbnail generation for background tabs
    [tabItem setView:tc.view];
    [tabItem bind:@"label" toObject:tc withKeyPath:@"title" options:nil];
    
    if (i == [tabView numberOfTabViewItems]) {
        [tabView addTabViewItem:tabItem]; // !! this apparently selects the new tab no matter what
    } else {
        [tabView insertTabViewItem:tabItem atIndex:i];
    }
    
    // must set this controller's window as host window or else Flash content won't play in background tabs
    [[tc webView] setHostWindow:[self window]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              tc, FUTabControllerKey,
                              [NSNumber numberWithInteger:[tabView numberOfTabViewItems] - 1], FUIndexKey,
                              nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUWindowControllerDidOpenTabNotification object:self userInfo:userInfo];
}


- (void)removeTabController:(FUTabController *)tc {
    if (1 == [tabControllers count]) {
        [self closeWindow];
    } else {
        [self removeTabViewItem:[self tabViewItemForTabController:tc]];
    }
}


- (void)removeTabControllerAtIndex:(NSUInteger)i {
    FUTabController *tc = [self tabControllerAtIndex:i];
    [self removeTabController:tc];
}


- (void)selectTabController:(FUTabController *)tc {
    self.selectedTabIndex = [tabView indexOfTabViewItem:[self tabViewItemForTabController:tc]];
    //[[self window] makeFirstResponder:locationComboBox];
}


- (FUTabController *)tabControllerAtIndex:(NSInteger)i {
    if (i < 0 || i > [tabView numberOfTabViewItems] - 1) {
        return nil;
    }
    NSTabViewItem *tabItem = [tabView tabViewItemAtIndex:i];
    return [tabItem identifier];
}


- (FUTabController *)lastTabController {
    return [self tabControllerAtIndex:[tabView numberOfTabViewItems] - 1];
}


- (FUTabController *)tabControllerForWebView:(WebView *)wv {
    for (FUTabController *tc in tabControllers) {
        if (wv == [tc webView]) {
            return tc;
        }
    }
    return nil;
}


- (NSInteger)indexOfTabController:(FUTabController *)tc {
    NSInteger i = 0;
    for (NSTabViewItem *tabItem in [tabView tabViewItems]) {
        if ([tabItem identifier] == tc) {
            return i;
        }
        i++;
    }
    return NSNotFound;
}


- (NSMenu *)contextMenuForTabAtIndex:(NSUInteger)i {
    NSTabViewItem *tabViewItem = [tabView tabViewItemAtIndex:i];
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSMenuItem *item = nil;
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Close Tab", @"")
                                       action:@selector(takeTabIndexToCloseFrom:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:tabViewItem];
    [item setOnStateImage:nil];
    [item setTag:i];
    [menu addItem:item];
    
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Move Tab to New Window", @"")
                                       action:@selector(takeTabIndexToMoveToNewWindowFrom:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:tabViewItem];
    [item setOnStateImage:nil];
    [item setTag:i];
    [menu addItem:item];    
    
    FUTabController *tc = [self tabControllerAtIndex:i];
    
    if ([tc canReload]) {
        [menu addItem:[NSMenuItem separatorItem]];
        
        item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reload Tab", @"")
                                           action:@selector(takeTabIndexToReloadFrom:) 
                                    keyEquivalent:@""] autorelease];
        [item setTarget:self];
        [item setRepresentedObject:tabViewItem];
        [item setOnStateImage:nil];
        [item setTag:i];
        [menu addItem:item];
    }
    
    return menu;
}


- (NSArray *)webViews {
    NSMutableArray *wvs = [NSMutableArray arrayWithCapacity:[tabView numberOfTabViewItems]];
    for (NSTabViewItem *tabItem in [tabView tabViewItems]) {
        [wvs addObject:[[tabItem identifier] webView]];
    }
    return [[wvs copy] autorelease];
}


- (NSViewController *)plugInViewControllerForPlugInIdentifier:(NSString *)s {
    FUPlugInWrapper *wrap = [[FUPlugInController instance] plugInWrapperForIdentifier:s];
    return [wrap plugInViewControllerForWindowNumber:[[self window] windowNumber]];
}


- (NSInteger)selectedTabIndex {
    NSTabViewItem *tabItem = [tabView selectedTabViewItem];
    if (tabItem) {
        return [tabView indexOfTabViewItem:tabItem];
    } else {
        return -1;
    }
}


- (void)setSelectedTabIndex:(NSInteger)i {
    if (NSNotFound == i || i < 0) return;
    if (i > [tabView numberOfTabViewItems] - 1) return;
    
    // don't reselect the same tab. it effs up the priorSelectedTabIndex
    NSInteger currentSelectedTabIndex = self.selectedTabIndex;
    if (i == currentSelectedTabIndex) return;
    
    priorSelectedTabIndex = currentSelectedTabIndex;
    [tabView selectTabViewItemAtIndex:i];
}


#pragma mark -
#pragma mark NSMenuValidation

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL action = [item action];
    
    if (action == @selector(setDisplayMode:) || action == @selector(setSizeMode:)) { // no changing the toolbar modes
        return NO;
    } else if (action == @selector(newTab:)) {
        return [[FUUserDefaults instance] tabbedBrowsingEnabled];
    } else if (action == @selector(selectNextTab:) || action == @selector(selectPreviousTab:)) {
        id responder = [[self window] firstResponder];
        return ![responder isKindOfClass:[NSTextView class]] && [tabView numberOfTabViewItems] > 1;
    } else if (action == @selector(viewSource:)) {
        return ![[[self selectedTabController] webView] isLoading] && [[[self selectedTabController] URLString] length];
    } else if (action == @selector(webStopLoading:)) {
        return [[[self selectedTabController] webView] isLoading];
    } else if (action == @selector(webReload:) || action == @selector(addBookmark:)) {
        return [[[self selectedTabController] URLString] length];
    } else if (action == @selector(webGoBack:)) {
        return [[[self selectedTabController] webView] canGoBack];
    } else if (action == @selector(webGoForward:)) {
        return [[[self selectedTabController] webView] canGoForward];
    } else if (action == @selector(webGoHome:)) {
        return [[[FUUserDefaults instance] homeURLString] length];
    } else if (action == @selector(zoomIn:)) {
        return [[self selectedTabController] canZoomIn];
    } else if (action == @selector(zoomOut:)) {
        return [[self selectedTabController] canZoomOut];
    } else if (action == @selector(actualSize:)) {
        return [[self selectedTabController] canActualSize];
    } else {
        return YES;
    }
}


#pragma mark -
#pragma mark NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView *)sv canCollapseSubview:(NSView *)subview {
    return subview == [[sv subviews] objectAtIndex:1];
}


- (BOOL)splitView:(NSSplitView *)sv shouldHideDividerAtIndex:(NSInteger)dividerIndex {
    return NO;
}


- (void)splitView:(NSSplitView *)sv resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSArray *views = [sv subviews];
    NSView *leftView = [views objectAtIndex:0];
    NSView *rightView = [views objectAtIndex:1];
    NSRect leftRect = [leftView frame];
    NSRect rightRect = [rightView frame];
    
    CGFloat dividerThickness = [sv dividerThickness];
    NSRect newFrame = [sv frame];

    leftRect.size.height = newFrame.size.height;
    rightRect.size.height = newFrame.size.height;
    leftRect.origin = NSMakePoint(0, 0);

    BOOL collapsed = NO;
    if (newFrame.size.width < 250) {
        collapsed = YES;
        leftRect.size.width = newFrame.size.width - dividerThickness;
        if (leftRect.size.width < MIN_COMBOBOX_WIDTH) {
            leftRect.size.width = MIN_COMBOBOX_WIDTH;
        }
        rightRect.origin = NSMakePoint(leftRect.size.width + dividerThickness, 0);
        rightRect.size.width = 0;
    } else {
        leftRect.size.width = newFrame.size.width - rightRect.size.width - dividerThickness;
        if (leftRect.size.width < MIN_COMBOBOX_WIDTH) {
            leftRect.size.width = MIN_COMBOBOX_WIDTH;
        }
        rightRect.origin.x = leftRect.size.width + dividerThickness;
    }
    
	[leftView setFrame:leftRect];
	[rightView setFrame:rightRect];

    if (collapsed) {
        NSRect locFrame = [locationComboBox frame];
        locFrame.size.width = NSInsetRect([leftView bounds], 4, 0).size.width;
        [locationComboBox setFrame:locFrame];
        
        [searchField setFrame:NSInsetRect([rightView bounds], 4, 0)];
    }
    
}


- (CGFloat)splitView:(NSSplitView *)sv constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
    return MIN_COMBOBOX_WIDTH;
}


- (CGFloat)splitView:(NSSplitView *)sv constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
    return NSWidth([sv frame]) - MIN_COMBOBOX_WIDTH;
}


#pragma mark -
#pragma mark NSControl Text

- (void)controlTextDidBeginEditing:(NSNotification *)n {
    NSControl *control = [n object];
    
    if (control == locationComboBox) {
        // TODO ? use binding instead?
        [locationComboBox showDefaultIcon];
    } else if (control == findPanelSearchField) {
        typingInFindPanel = YES;
    }
}


- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    if (control == locationComboBox) {
        [[FURecentURLController instance] resetMatchingRecentURLs];
        displayingMatchingRecentURLs = YES;
        return YES;
    } else {
        return YES;
    }
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    if (control == locationComboBox) {
//        [locationComboField hidePopUp];
        displayingMatchingRecentURLs = NO;
        return YES;
    } else if (control == findPanelSearchField) {
        return [self findPanelSearchField:control textShouldEndEditing:fieldEditor];
    } else {
        return YES;
    }
}


- (BOOL)findPanelSearchField:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    NSEvent *evt = [NSApp currentEvent];    
    BOOL result = NO;
    
    if (!typingInFindPanel) {
        result = YES;
    } else if ([evt isKeyUpOrDown]) {
        if ([evt isCommandKeyPressed] ||
            [evt isOptionKeyPressed] ||
            [evt isCommandKeyPressed] ||
            [evt isEscKeyPressed] ||
            [evt isReturnKeyPressed] ||
            [evt isEnterKeyPressed]) {
            result = YES;
        }
    }
    
    return result;
}


// necessary to handle cmd-Return in search field
- (BOOL)control:(NSControl *)control textView:(NSTextView *)tv doCommandBySelector:(SEL)sel {
    if (control == searchField) {
        BOOL isCommandClick = [[[self window] currentEvent] isCommandKeyPressed];
        
        if (@selector(noop:) == sel && isCommandClick) {
            [self search:control];
            return YES;
        }
    }
    
    return NO;
}


- (void)controlTextDidChange:(NSNotification *)n {
    NSControl *control = [n object];
    
    if (control == findPanelSearchField) {
        WebView *wv = [[self selectedTabController] webView];
        DOMRange *r = [wv selectedDOMRange];
        [r collapse:YES];
        [wv setSelectedDOMRange:r affinity:NSSelectionAffinityUpstream];
        [self find:findPanelSearchField];
    } else if (control == locationComboBox) {
        [[FURecentURLController instance] resetMatchingRecentURLs];
        
        NSUInteger i = 0;
        for (NSString *URLString in [self recentURLs]) {
            URLString = [URLString stringByTrimmingURLSchemePrefix];
            if ([URLString hasPrefix:[locationComboBox stringValue]]) {
                [self addMatchingRecentURL:URLString];
                if (i++ > 20) { // TODO
                    break;
                }
            }
        }
    }
}


- (void)controlTextDidEndEditing:(NSNotification *)n {
    NSControl *control = [n object];

    if (control == findPanelSearchField) {
        typingInFindPanel = NO;
    }
}


#pragma mark -
#pragma mark NSComboBoxDataSource

- (void)comboFieldWillDismiss:(TDComboField *)cf {
    if (cf == locationComboBox) {
//        NSInteger i = [locationComboBox indexOfSelectedItem];
//        NSInteger c = [locationComboBox numberOfItems];
        
//        // last item (clear url menu) was clicked. clear recentURLs
//        if (c && i == c - 1) {
//            if (![[NSApp currentEvent] isEscKeyPressed]) {
//                NSString *s = [locationComboBox stringValue];
//                [locationComboBox deselectItemAtIndex:i];
//                
//                [[FURecentURLController instance] resetRecentURLs];
//                [[FURecentURLController instance] resetMatchingRecentURLs];
//                
//                [locationComboBox reloadData];
//                [locationComboBox setStringValue:s];
//            }
//        }
    }
}


- (id)comboField:(TDComboField *)cb objectAtIndex:(NSUInteger)i {
    if (locationComboBox == cb) {
        NSArray *URLs = displayingMatchingRecentURLs ? [self matchingRecentURLs] : [self recentURLs];
        
        NSInteger c = [URLs count];
//        if (c && i == c) {
//            NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
//            return [[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Clear Recent URL Menu", @"") attributes:attrs] autorelease];
//        } else {
            if (i < c) {
                return [URLs objectAtIndex:i];
            } else {
                return nil;
            }
//        }
    } else {
        return nil;
    }
}


- (NSUInteger)numberOfItemsInComboField:(TDComboField *)cb {
    if (locationComboBox == cb) {
        NSArray *URLs = displayingMatchingRecentURLs ? [self matchingRecentURLs] : [self recentURLs];
        NSInteger c = [URLs count];
        return c; // + 1;
    } else {
        return 0;
    }
}


- (NSUInteger)comboField:(TDComboField *)cb indexOfItemWithStringValue:(NSString *)s {
    if (locationComboBox == cb) {
        if (displayingMatchingRecentURLs) {
            return [[self matchingRecentURLs] indexOfObject:s];
        }
        return [[self recentURLs] indexOfObject:s];
    } else {
        return 0;
    }
}


- (NSString *)comboField:(TDComboField *)cb completedString:(NSString *)uncompletedString {
    if ([[self window] isKeyWindow] && [self isToolbarVisible] && locationComboBox == cb) {
        if ([[self matchingRecentURLs] count]) {
            //[[locationComboField cell] scrollItemAtIndexToVisible:0];
            //[locationComboField showPopUpWithItemCount:[[self matchingRecentURLs] count]];
            return [[self matchingRecentURLs] objectAtIndex:0];
        }
        return nil;
    } else {
        return nil;
    }
}


#pragma mark -
#pragma mark HMImageComboBoxDelegate

- (BOOL)comboField:(TDComboField *)cb writeDataToPasteboard:(NSPasteboard *)pboard {
//- (BOOL)hmComboBox:(HMImageComboBox *)cb writeDataToPasteboard:(NSPasteboard *)pboard {
    if (locationComboBox == cb) {
        WebView *wv = [[self selectedTabController] webView];
        
        NSString *URLString = [wv mainFrameURL];
        if (![URLString length]) {
            return NO;
        }
        
        NSString *title = [wv mainFrameTitle];
        if (![title length]) {
            title = [URLString stringByTrimmingURLSchemePrefix];        
        }
        
        FUWriteAllToPasteboard(URLString, title, pboard);

        return YES;
    } else {
        return NO;
    }
}


#pragma mark -
#pragma mark NSTabViewDelegate

- (void)tabView:(NSTabView *)tv willSelectTabViewItem:(NSTabViewItem *)tabItem {
    if ([self selectedTabController]) {
        [self stopObservingTabController:[self selectedTabController]];
        self.selectedTabController = nil;
    }
}


- (void)tabView:(NSTabView *)tv didSelectTabViewItem:(NSTabViewItem *)tabItem {
    FUTabController *tc = [tabItem identifier];
    
    if ([tabControllers containsObject:tc]) { // if the tab was just dragged to this tabBar from another window, we will not have created a tabController yet
        
        FUTabController *oldtc = [self selectedTabController];
        self.selectedTabController = tc;
        if (oldtc && oldtc != tc) { // this check prevents double apple event firing
            [self selectTabController:tc]; // this fires apple event
        }
        [self startObservingTabController:tc];
        [self clearProgress];

        // if the tab has web content, select the webView. otherwise select the loc bar
        if ([selectedTabController canReload]) {
			[[self window] makeFirstResponder:[selectedTabController webView]];
		} else {
			[[self window] makeFirstResponder:locationComboBox];
		}
			
    }

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              tc, FUTabControllerKey,
                              [NSNumber numberWithInteger:priorSelectedTabIndex], FUPriorIndexKey,
                              [NSNumber numberWithInteger:self.selectedTabIndex], FUIndexKey,
                              nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUWindowControllerDidChangeSelectedTabNotification object:self userInfo:userInfo];
}


- (BOOL)tabView:(NSTabView *)tv shouldCloseTabViewItem:(NSTabViewItem *)tabItem {
    if (tabItem == [tabView selectedTabViewItem]) {
        closingSelectedTabIndex = [tabView indexOfTabViewItem:tabItem];
    } else {
        closingSelectedTabIndex = -1;
    }
    return YES;
}


- (void)tabView:(NSTabView *)tv didCloseTabViewItem:(NSTabViewItem *)tabItem {
    FUTabController *tc = [tabItem identifier];
    
    [self tabControllerWasRemovedFromTabBar:tc];

    // are we closing the currently selected tab?
    if (closingSelectedTabIndex != -1) {

        // then respect pref for returning to prior selected tab
        if ([[FUUserDefaults instance] selectPriorSelectedTabOnTabClose]) {
            self.selectedTabIndex = priorSelectedTabIndex;

        // otherwise select the *next* tab (NSTabView's default behavior is *previous*)
        } else  {
            // NSTabView behavior on closing a selected tab is to select the tab at the next lower index (prev)
            // However, most browsers instead select the next higher index (next)
            // this changes the NSTabView behavior to match browser behavior expectations
            NSInteger c = [tabView numberOfTabViewItems];
            NSUInteger i = closingSelectedTabIndex;
            BOOL selectNext = i != 0 && i != c;
            
            if (selectNext) {
                [self selectNextTab:self];
            }
        }
    }
}


- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tv {
    BOOL hiddenAlways = [[FUUserDefaults instance] tabBarHiddenAlways];
    BOOL hasMultiTabs = [tabBar numberOfVisibleTabs] > 1;
    
    BOOL hidden = hiddenAlways || !hasMultiTabs;
    [tabBar setHidden:hidden];
    
    [self updateEmptyTabBarLineVisibility];
    [self updateUberViewHeight];
}


#pragma mark -
#pragma mark PSMTabBarControl Dragging

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)tv {
    return [NSArray arrayWithObjects:WebURLsWithTitlesPboardType, NSURLPboardType, nil];    
}


- (void)tabView:(NSTabView *)tv acceptedDraggingInfo:(id <NSDraggingInfo>)draggingInfo onTabViewItem:(NSTabViewItem *)tabItem {
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];    
    NSURL *URL = [WebView URLFromPasteboard:pboard];
    
    FUTabController *tc = [tabItem identifier];
    [tc loadURL:[URL absoluteString]];
}


- (BOOL)tabView:(NSTabView *)tv shouldDragTabViewItem:(NSTabViewItem *)tabItem fromTabBar:(PSMTabBarControl *)tabBarControl {
    draggingTabIndex = [tabView indexOfTabViewItem:tabItem];
    return [tabView numberOfTabViewItems] > 1;
}


- (BOOL)tabView:(NSTabView *)tv shouldAllowTabViewItem:(NSTabViewItem *)tabItem toLeaveTabBar:(PSMTabBarControl *)tabBarControl {
    if ([tabView numberOfTabViewItems] < 2) {
        return NO;
    }
    
    departingTabController = [tabItem identifier];

    return YES;
}


- (BOOL)tabView:(NSTabView *)tv shouldDropTabViewItem:(NSTabViewItem *)tabItem inTabBar:(PSMTabBarControl *)tabBarControl {
    return YES;
}


- (void)tabView:(NSTabView *)tv didDropTabViewItem:(NSTabViewItem *)tabItem inTabBar:(PSMTabBarControl *)tabBarControl {
    if (tabBarControl == tabBar) { // dropped on originating window.
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                              [tabItem identifier], FUTabControllerKey,
                              [NSNumber numberWithInteger:[tabView indexOfTabViewItem:tabItem]], FUIndexKey,
                              [NSNumber numberWithInteger:draggingTabIndex], FUPriorIndexKey,
                              nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:FUWindowControllerDidChangeTabOrderNotification object:self userInfo:info];

    } else { // dropped on other window
        [self tabControllerWasRemovedFromTabBar:departingTabController];
        
        FUWindowController *wc = [(FUTabBarControl *)tabBarControl windowController];
        [wc tabControllerWasDroppedOnTabBar:departingTabController];
        
        // must call this manually
        [wc tabView:wc.tabView didSelectTabViewItem:[wc tabViewItemForTabController:departingTabController]];
    }
}


- (NSImage *)tabView:(NSTabView *)tv imageForTabViewItem:(NSTabViewItem *)tabItem offset:(NSSize *)offset styleMask:(unsigned int *)styleMask {
    if (styleMask) {
        *styleMask = NSTitledWindowMask|NSTexturedBackgroundWindowMask;
    }
    
    FUWebView *wv = (FUWebView *)[[tabItem identifier] webView];
    
    return [wv documentViewImageWithCurrentAspectRatio];
}


#pragma mark -
#pragma mark NSWindowNotifications
// dont need to register for these explicity

- (void)windowDidResignKey:(NSNotification *)n {
    //[locationComboField hidePopUp];
}


- (void)windowDidMove:(NSNotification *)n {
    [self saveFrameString];
}


- (void)windowDidResize:(NSNotification *)n {
    [self updateContentViewFrame];
    [self saveFrameString];
}


- (void)windowDidChangeScreen:(NSNotification *)n {
    NSInteger i = [[NSScreen screens] indexOfObject:[[self window] screen]];
    [[FUUserDefaults instance] setWindowScreenIndex:i];
}


- (void)windowWillClose:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] postNotificationName:FUWindowControllerWillCloseNotification object:self];
}


#pragma mark -
#pragma mark FUTabControllerNotifications

- (void)tabControllerProgressDidStart:(NSNotification *)n {
    [self clearProgress];
}


- (void)tabControllerProgressDidChange:(NSNotification *)n {
    FUTabController *tc = [n object];
    if (tc == [self selectedTabController]) {
        [self displayEstimatedProgress];
    }
}


- (void)tabControllerProgressDidFinish:(NSNotification *)n {
    FUTabController *tc = [n object];
    if (tc == [self selectedTabController]) {
        WebView *wv = [tc webView];
        if ([[wv mainFrameURL] hasPrefix:kFUAboutBlank]) {
            [locationComboBox setStringValue:[[[wv backForwardList] currentItem] URLString]];
        } else {
            tc.lastLoadFailed = NO;
        }
        [self clearProgressInFuture];
    }
}


- (void)tabControllerDidStartProvisionalLoad:(NSNotification *)n {
    // hide find panel
    self.typingInFindPanel = NO;
    [self hideFindPanel:self];
    
    // hide toolbar if appropriate
    if (![[FUUserDefaults instance] toolbarShown]) {
        [[[self window] toolbar] setVisible:NO];
    }
}


- (void)tabControllerDidCommitLoad:(NSNotification *)n {
    FUTabController *tc = [n object];
    
    NSString *finalURLString = tc.URLString;
    NSString *initialURLString = tc.initialURLString;
    
    [self addRecentURL:finalURLString];
    [self addRecentURL:initialURLString]; // if they are the same, this will not be added
}


#pragma mark -
#pragma mark Private

- (void)setUpTabBar {
    self.tabView = [[[NSTabView alloc] initWithFrame:NSZeroRect] autorelease];
    [tabView setTabViewType:NSNoTabsNoBorder];
    [tabView setDrawsBackground:NO];
    [tabView setDelegate:tabBar];
    [tabView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    
    [tabBar setDelegate:self];
    [tabBar setPartnerView:uberView];
    [tabBar setTabView:tabView];
    
    [tabBar setStyleNamed:@"Adium"];
    [tabBar setTearOffStyle:PSMTabBarTearOffMiniwindow];
    [tabBar setUseOverflowMenu:YES];
    [tabBar setAllowsScrubbing:YES];
    [tabBar setHideForSingleTab:[[FUUserDefaults instance] tabBarHiddenForSingleTab]];
    [tabBar setShowAddTabButton:NO];
    [tabBar setCellOptimumWidth:[[FUUserDefaults instance] tabBarCellOptimumWidth]];
    [[tabBar addTabButton] setTarget:self];
    [[tabBar addTabButton] setAction:@selector(newTab:)];
    
    uberView.midView = tabView;
    
    emptyTabBarLine.mainColor = [NSColor colorWithDeviceWhite:.1 alpha:1];
    emptyTabBarLine.nonMainColor = [NSColor darkGrayColor];
}


- (void)closeWindow {
    BOOL onlyHide = [[FUUserDefaults instance] hideLastClosedWindow];
    BOOL onlyOneWin = (1 == [[[FUDocumentController instance] documents] count]);
    if (onlyHide && onlyOneWin) {
        [[FUDocumentController instance] setHiddenWindow:[self window]];
        [[self window] orderOut:self];
    } else {
        [(FUWindow *)[self window] forcePerformClose:self];
    }
}
- (BOOL)windowShouldClose:(id)sender {
	[[FUDocumentController instance] setHiddenWindow:[self window]];
	[[self window] orderOut:self];
	return FALSE;
}


- (void)closeTab {
    NSTabViewItem *tabItem = [tabView selectedTabViewItem];
    [self removeTabViewItem:tabItem];    
}


- (BOOL)removeTabViewItem:(NSTabViewItem *)tabItem {
    FUTabController *tc = [tabItem identifier];

    // must call this manually
    if (![self tabView:tabView shouldCloseTabViewItem:tabItem]) {
        return NO;
    }
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              tc, FUTabControllerKey,
                              [NSNumber numberWithInteger:[tabView indexOfTabViewItem:tabItem]], FUIndexKey,
                              nil];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:FUWindowControllerWillCloseTabNotification object:self userInfo:userInfo];
    
    [[tc webView] setHostWindow:nil];
    
    [tabView removeTabViewItem:tabItem]; // triggers -stopObservingTabController:
    [tabControllers removeObject:[[tc retain] autorelease]];
    
    [nc postNotificationName:FUWindowControllerDidCloseTabNotification object:self userInfo:userInfo];
    return YES;
}


- (void)tabControllerWasRemovedFromTabBar:(FUTabController *)tc {
    [[tc retain] autorelease];
    
    if (tc == [self selectedTabController]) {
        self.selectedTabController = nil;
        [self stopObservingTabController:tc];
    }
    
    [tabControllers removeObject:tc];
}


- (void)saveFrameString {
    if (suppressNextFrameStringSave) {
        self.suppressNextFrameStringSave = NO;
    } else {
        NSString *s = [[self window] stringWithSavedFrame];
        [[FUUserDefaults instance] setWindowFrameString:s];
    }
}


- (void)startObservingTabController:(FUTabController *)tc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(tabControllerProgressDidStart:) name:FUTabControllerProgressDidStartNotification object:tc];
    [nc addObserver:self selector:@selector(tabControllerProgressDidChange:) name:FUTabControllerProgressDidChangeNotification object:tc];
    [nc addObserver:self selector:@selector(tabControllerProgressDidFinish:) name:FUTabControllerProgressDidFinishNotification object:tc];
    [nc addObserver:self selector:@selector(tabControllerDidStartProvisionalLoad:) name:FUTabControllerDidStartProvisionalLoadNotification object:tc];
    [nc addObserver:self selector:@selector(tabControllerDidCommitLoad:) name:FUTabControllerDidCommitLoadNotification object:tc];
    
    // bind title
    [[self window] bind:@"title" toObject:tc withKeyPath:@"title" options:nil];
    
    // bind URLString
    [locationComboBox bind:@"stringValue" toObject:tc withKeyPath:@"URLString" options:nil];
        
    // bind icon
    [locationComboBox bind:@"image" toObject:tc withKeyPath:@"favicon" options:nil];

    // bind status text
    [statusTextField bind:@"stringValue" toObject:tc withKeyPath:@"statusText" options:nil];
}


- (void)stopObservingTabController:(FUTabController *)tc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:FUTabControllerProgressDidStartNotification object:tc];
    [nc removeObserver:self name:FUTabControllerProgressDidChangeNotification object:tc];
    [nc removeObserver:self name:FUTabControllerProgressDidFinishNotification object:tc];
    [nc removeObserver:self name:FUTabControllerDidStartProvisionalLoadNotification object:tc];
    [nc removeObserver:self name:FUTabControllerDidCommitLoadNotification object:tc];

    // unbind title
    [[self window] unbind:@"title"];
    
    // unbind URLString
    [locationComboBox unbind:@"stringValue"];
    
    // unbind icon
    [locationComboBox unbind:@"image"];    

    // unbind status text
    [statusTextField unbind:@"stringValue"];
}


- (void)tabControllerWasDroppedOnTabBar:(FUTabController *)tc {
    if (![tabControllers containsObject:tc]) { // TODO is this necessary since this is an NSMutableSet?
        [tabControllers addObject:tc];
    }
}


- (NSInteger)preferredIndexForNewTab {
    NSInteger i = [tabView numberOfTabViewItems];
    return i;
}


- (FUTabController *)tabControllerForCommandClick:(FUActivation *)act {
    BOOL inTab = [[FUUserDefaults instance] tabbedBrowsingEnabled];
    BOOL select = [[FUUserDefaults instance] selectNewWindowsOrTabsAsCreated];
    
    select = act.isShiftKeyPressed ? !select : select;
    inTab = act.isOptionKeyPressed ? !inTab : inTab;
    
    if (inTab) {
        // using actions here to route thru scripting for recording
        if (select) {
            [self newTab:self];
        } else {
            [self newBackgroundTab:self];
        }
        
        NSInteger i = [tabView numberOfTabViewItems] - 1;
        return [self tabControllerAtIndex:i];
    } else {
        FUDocument *doc = [[FUDocumentController instance] openDocumentWithURL:nil makeKey:select];
        return [[doc windowController] selectedTabController];
    }
}


- (void)handleCommandClick:(FUActivation *)act URL:(NSString *)s {
    FUTabController *tc = [self tabControllerForCommandClick:act];
    NSAssert(tc, @"");
    [tc loadURL:s];
}


- (NSTabViewItem *)tabViewItemForTabController:(FUTabController *)tc {
    for (NSTabViewItem *tabItem in [tabView tabViewItems]) {
        if (tc == [tabItem identifier]) {
            return tabItem;
        }
    }
    return nil;
}


- (void)displayEstimatedProgress {
    CGFloat progress = [[self selectedTabController] estimatedProgress];
    locationComboBox.progress = progress;
    
    if (![self isToolbarVisible]) {
        [statusProgressIndicator setHidden:NO];
    }
}


- (void)clearProgressInFuture {
    [self performSelector:@selector(clearProgress) withObject:nil afterDelay:.2];
}



- (void)clearProgress {
    locationComboBox.progress = 0;
    [statusProgressIndicator setHidden:YES];
}


- (BOOL)isToolbarVisible {
    return [[[self window] toolbar] isVisible];
}


- (void)showToolbarTemporarilyIfHidden {
    if (![self isToolbarVisible]) {
        [self showToolbarTemporarily];
    }
}


- (void)showToolbarTemporarily {
    [(FUWindowToolbar *)[[self window] toolbar] showTemporarily];
}


- (void)removeDocumentIconButton {
    [[[self window] standardWindowButton:NSWindowDocumentIconButton] setFrame:NSZeroRect];
}


- (NSArray *)recentURLs {
    return [[FURecentURLController instance] recentURLs];
}


- (NSArray *)matchingRecentURLs {
    return [[FURecentURLController instance] matchingRecentURLs];
}


- (void)addRecentURL:(NSString *)s {
    [[FURecentURLController instance] addRecentURL:s];
}


- (void)addMatchingRecentURL:(NSString *)s {
    [[FURecentURLController instance] addMatchingRecentURL:s];
}


- (void)editBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(FUBookmark *)bmark {
    [bmark autorelease]; // released
    
    if (NSOKButton == code) {
        bmark.title = editingBookmark.title;
        
        [[FUBookmarkController instance] save];
        [[NSNotificationCenter defaultCenter] postNotificationName:FUBookmarksDidChangeNotification object:nil];
    }
    
    self.editingBookmark = nil;
}


- (void)toolbarShownDidChange:(NSNotification *)n {
    [self updateEmptyTabBarLineVisibility];
    [self updateUberViewHeight];
    [self updateContentViewFrame];
    
    [tabBar setNeedsDisplay:YES];
    [bookmarkBar setNeedsDisplay:YES];
}


- (void)tabBarShownDidChange:(NSNotification *)n {
    BOOL hiddenAlways = [[FUUserDefaults instance] tabBarHiddenAlways];
    [tabBar setHidden:hiddenAlways];
    [tabBar setNeedsDisplay:YES];
    
    [self updateEmptyTabBarLineVisibility];
    [self updateUberViewHeight];
}


- (void)tabBarHiddenForSingleTabDidChange:(NSNotification *)n {
    [tabBar setHideForSingleTab:[[FUUserDefaults instance] tabBarHiddenForSingleTab]];
}


- (void)bookmarkBarShownDidChange:(NSNotification *)n {
    BOOL hidden = ![[FUUserDefaults instance] bookmarkBarShown];
    
    if (hidden && [bookmarkBar isHidden]) {
        return;
    } else if (!hidden && ![bookmarkBar isHidden]) {
        return;
    }

    CGFloat height = NSHeight([bookmarkBar bounds]);
    [bookmarkBar setHidden:hidden];
    
    NSSize oldContainerSize = [tabContainerView frame].size;
    NSSize newContainerSize = oldContainerSize;
    
    if (hidden) {
        newContainerSize.height += height;
    } else {
        newContainerSize.height -= height;
    }
    
    [tabContainerView setFrameSize:newContainerSize];

    [self updateEmptyTabBarLineVisibility];
    [self updateUberViewHeight];

    [bookmarkBar setNeedsDisplay:YES];
    [tabBar setNeedsDisplay:YES];
}


- (void)statusBarShownDidChange:(NSNotification *)n {
    [self hideFindPanel:self];
    
    BOOL hidden = ![[FUUserDefaults instance] statusBarShown];
    
    if (hidden && [statusBar isHidden]) {
        return;
    } else if (!hidden && ![statusBar isHidden]) {
        return;
    }
    
    CGFloat height = NSHeight([statusBar bounds]);
    [statusBar setHidden:hidden];
    
    NSPoint oldContainerOrigin = [tabContainerView frame].origin;
    NSPoint newContainerOrigin = oldContainerOrigin;
    
    NSSize oldContainerSize = [tabContainerView frame].size;
    NSSize newContainerSize = oldContainerSize;
    
    if (hidden) {
        newContainerOrigin.y -= height;
        newContainerSize.height += height;
    } else {
        newContainerOrigin.y += height;
        newContainerSize.height -= height;
    }
    
    [tabContainerView setFrameOrigin:newContainerOrigin];
    [tabContainerView setFrameSize:newContainerSize];
    
    [findPanelView setNeedsDisplay:YES];
    [statusBar setNeedsDisplay:YES];
    [tabContainerView setNeedsDisplay:YES];
    [tabBar setNeedsDisplay:YES];
    [bookmarkBar setNeedsDisplay:YES];
    [[[self selectedTabController] webView] setNeedsDisplay:YES];
}


- (void)updateEmptyTabBarLineVisibility {
    //BOOL bookmarkBarShown = [[FUUserDefaults instance] bookmarkBarShown];
    BOOL toolbarShown = [self isToolbarVisible];
    BOOL hasMultipleTabs = [tabBar numberOfVisibleTabs] > 1;
    BOOL tabBarShown = hasMultipleTabs && ![[FUUserDefaults instance] tabBarHiddenAlways] && ![tabBar isHidden];
    
    BOOL lineShown = NO;
    if (toolbarShown && !tabBarShown) {
        lineShown = YES;
    } else if (!toolbarShown && !tabBarShown) {
        lineShown = YES;
    }

    [emptyTabBarLine setHidden:!lineShown];
    [emptyTabBarLine setNeedsDisplay:YES];    
}


- (void)updateUberViewHeight {
    NSRect containerFrame = [tabContainerView frame];
    CGFloat uberFrameHeight = containerFrame.size.height;
    
    NSInteger num = [tabBar numberOfVisibleTabs];
    BOOL hasMultipleTabs = num > 1;
    BOOL hiddenAlways = [[FUUserDefaults instance] tabBarHiddenAlways];
    BOOL tabBarShown = hasMultipleTabs && !hiddenAlways && ![tabBar isHidden];
    if (tabBarShown) {
        CGFloat tabBarHeight = NSHeight([tabBar frame]);
        uberFrameHeight -= tabBarHeight;
    }

    BOOL bookmarkBarShown = [[FUUserDefaults instance] bookmarkBarShown];
    if (bookmarkBarShown && !tabBarShown) {
        uberFrameHeight -= 1;
    }
    
    if (!bookmarkBarShown && !tabBarShown) {
        uberFrameHeight -= 1;
    }

    NSRect uberFrame = [uberView frame];
    uberFrame.size.height = uberFrameHeight;
    [uberView setFrame:uberFrame];
    [uberView setNeedsDisplay:YES];
}


- (void)updateContentViewFrame {
    NSWindow *win = [self window];
    NSRect contentFrame = [[win contentView] frame];
    NSRect winFrame = [win frame];
    CGFloat contentHeight = NSHeight([NSWindow contentRectForFrameRect:winFrame styleMask:[win styleMask]]);
    
    if ([self isToolbarVisible]) {
        contentFrame.size.height = contentHeight - TOOLBAR_HEIGHT;
    } else {
        contentFrame.size.height = contentHeight + 1;
    }
    [[win contentView] setFrame:contentFrame];
    [[win contentView] setNeedsDisplay:YES];
}


- (void)toggleFindPanel:(BOOL)show {
    [[[self selectedTabController] webView] unmarkAllTextMatches];
    
    BOOL statusBarShown = [[FUUserDefaults instance] statusBarShown];
    
    CGFloat statusBarHeight = statusBarShown ? NSHeight([statusBar bounds]) : 0;
    CGFloat findPanelHeight = NSHeight([findPanelView bounds]);
    
    NSPoint oldContainerOrigin = [tabContainerView frame].origin;
    NSPoint newContainerOrigin = oldContainerOrigin;
    
    NSSize oldContainerSize = [tabContainerView frame].size;
    NSSize newContainerSize = oldContainerSize;
    
    if (show) {
        NSView *contentView = [[self window] contentView];
        
        newContainerOrigin.y += findPanelHeight;
        newContainerSize.height -= findPanelHeight;
        [findPanelView setFrameSize:NSMakeSize(NSWidth([contentView bounds]), NSHeight([findPanelView bounds]))];
        [findPanelView setFrameOrigin:NSMakePoint(0, statusBarHeight)];
        [contentView addSubview:findPanelView];
        [[self window] makeFirstResponder:findPanelSearchField];
    } else {
        [findPanelView removeFromSuperview];
        newContainerOrigin.y -= findPanelHeight;
        newContainerSize.height += findPanelHeight;
        [[self window] makeFirstResponder:[[self selectedTabController] webView]];
    }
    
    [tabContainerView setFrameOrigin:newContainerOrigin];
    [tabContainerView setFrameSize:newContainerSize];
    
    [findPanelView setNeedsDisplay:YES];
    [statusBar setNeedsDisplay:YES];
    [tabContainerView setNeedsDisplay:YES];
    [tabBar setNeedsDisplay:YES];
    [bookmarkBar setNeedsDisplay:YES];
    [[[self selectedTabController] webView] setNeedsDisplay:YES];
}

@synthesize locationSplitView;
@synthesize locationComboBox;
@synthesize searchField;
@synthesize tabContainerView;
@synthesize tabBar;
@synthesize emptyTabBarLine;
@synthesize bookmarkBar;
@synthesize uberView;
@synthesize statusBar;
@synthesize statusTextField;
@synthesize statusProgressIndicator;
@synthesize findPanelView;
@synthesize findPanelSearchField;
@synthesize editBookmarkSheet;
@synthesize editingBookmark;
@synthesize tabView;
@synthesize departingTabController;
@synthesize viewSourceController;
@synthesize shortcutController;
@synthesize tabControllers;
@synthesize selectedTabController;
@synthesize currentTitle;
@synthesize findPanelTerm;
@synthesize typingInFindPanel;
@synthesize suppressNextFrameStringSave;
@end
