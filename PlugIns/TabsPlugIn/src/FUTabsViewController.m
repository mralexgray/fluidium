//
//  FUTabsViewController.m
//  TabsPlugIn
//
//  Created by Todd Ditchendorf on 12/25/09.
//  Copyright 2009 Todd Ditchendorf. All rights reserved.
//

#import "FUTabsViewController.h"
#import "FUNotifications.h"
#import "FUPlugIn.h"
#import "FUPlugInAPI.h"
#import "FUTabsPlugIn.h"
#import "FUImageBrowserItem.h"
#import <Quartz/Quartz.h>
#import <WebKit/WebKit.h>

#if FU_BUILD_TARGET_LEOPARD
@class IKImageBrowserCell;

NSInteger IKImageStateReady = 2;

@interface NSObject ()
// IKImageBrowserView
- (void)setIntercellSpacing:(NSSize)size;
- (id)cellForItemAtIndex:(NSInteger)i;

// IKImageBrowserCell
- (NSInteger)cellState;
@end
#endif

@interface NSObject ()
// FUWindowController
- (void)setSelectedTabIndex:(NSInteger)i;
- (NSArray *)tabControllers;
- (void)startObserveringTabController:(id)tc;
- (void)stopObserveringTabController:(id)tc;
@end

@interface WebView ()
- (NSBitmapImageRep *)squareBitmapImageRepOfWebContent;
@end

@interface FUTabsViewController ()
- (NSArray *)webViews;
- (void)updateImageBrowserItemLaterAtIndex:(NSNumber *)indexObj;
- (void)updateImageBrowserItemAtIndex:(NSInteger)i;
- (void)updateImageBrowserItem:(FUImageBrowserItem *)item fromWebView:(WebView *)wv;
- (NSBitmapImageRep *)thumbnailFromWebView:(WebView *)wv;
@end

@implementation FUTabsViewController

- (id)init {
    return [self initWithNibName:@"FUTabsView" bundle:[NSBundle bundleForClass:[self class]]];
}


- (id)initWithNibName:(NSString *)name bundle:(NSBundle *)b {
    if (self = [super initWithNibName:name bundle:b]) {
        
    }
    return self;
}


- (void)dealloc {
    self.view = nil;
    self.imageBrowserView = nil;
    self.plugIn = nil;
    self.plugInAPI = nil;
    self.imageBrowserItems = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    [imageBrowserView setValue:[NSColor colorWithDeviceWhite:.9 alpha:1] forKey:IKImageBrowserBackgroundColorKey];
    [imageBrowserView setValue:[NSColor lightGrayColor] forKey:IKImageBrowserCellsOutlineColorKey];

    //[imageBrowserView setCellSize:NSMakeSize(600, 400)];

    [imageBrowserView setZoomValue:1.0];
	[imageBrowserView setConstrainsToOriginalSize:NO];
	[imageBrowserView setContentResizingMask:NSViewHeightSizable];
	[imageBrowserView setAllowsEmptySelection:NO];
	[imageBrowserView setAllowsMultipleSelection:NO];
	[imageBrowserView setDelegate:self];
	[imageBrowserView setDataSource:self];

    // snow leopard only
    if ([imageBrowserView respondsToSelector:@selector(setIntercellSpacing:)]) {
        [imageBrowserView setIntercellSpacing:NSMakeSize(8, 8)];
    }
}


#pragma mark -
#pragma mark Public

- (void)viewDidAppear {
    NSArray *wvs = [self webViews];
    self.imageBrowserItems = [NSMutableArray arrayWithCapacity:[wvs count]];
    
    for (WebView *wv in wvs) {
        FUImageBrowserItem *item = [[[FUImageBrowserItem alloc] init] autorelease];
        [self updateImageBrowserItem:item fromWebView:wv];
        [imageBrowserItems addObject:item];
    }
    
    [imageBrowserView reloadData];

    id wc = [[self.view window] windowController];
    for (id tc in [wc tabControllers]) {
        [self startObserveringTabController:tc];
    }
}


- (void)viewWillDisappear {
    self.imageBrowserItems = nil;
    [imageBrowserView reloadData];
}


#pragma mark -
#pragma mark IKImageBrowserDataSource

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)ib {
    return [imageBrowserItems count];
}


- (id /*IKImageBrowserItem*/)imageBrowser:(IKImageBrowserView *)ib itemAtIndex:(NSUInteger)i {
    return [imageBrowserItems objectAtIndex:i];
}


#pragma mark -
#pragma mark IKImageBrowserDelegate

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)ib {
    id wc = [[self.view window] windowController];
    [wc setSelectedTabIndex:[[ib selectionIndexes] firstIndex]];
}


#pragma mark -
#pragma mark FUWindowControllerNotifcations

- (void)windowControllerDidOpenTab:(NSNotification *)n {
    NSInteger i = [[[n userInfo] objectForKey:@"FUIndex"] integerValue];
    WebView *wv = [[self webViews] objectAtIndex:i];
    FUImageBrowserItem *item = [[[FUImageBrowserItem alloc] init] autorelease];
    [self updateImageBrowserItem:item fromWebView:wv];
    [imageBrowserItems insertObject:item atIndex:i];
    [imageBrowserView reloadData];
    
    id tc = [[n userInfo] objectForKey:@"FUTabController"];
    [self startObserveringTabController:tc];
}


- (void)windowControllerWillCloseTab:(NSNotification *)n {
    NSInteger i = [[[n userInfo] objectForKey:@"FUIndex"] integerValue];
    [imageBrowserItems removeObjectAtIndex:i];
    [imageBrowserView reloadData];
    
    id tc = [[n userInfo] objectForKey:@"FUTabController"];
    [self stopObserveringTabController:tc];
}


- (void)windowControllerDidChangeSelectedTab:(NSNotification *)n {
    NSInteger i = [[[n userInfo] objectForKey:@"FUIndex"] integerValue];
    [imageBrowserView setSelectionIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
    
    if (i < [imageBrowserItems count]) {
        // snow leopard only
        if ([imageBrowserView respondsToSelector:@selector(cellForItemAtIndex:)]) {
            IKImageBrowserCell *cell = [imageBrowserView cellForItemAtIndex:i];
            if (IKImageStateReady != [cell cellState]) {
                [self updateImageBrowserItemAtIndex:i];
            }
        } else {
            [self updateImageBrowserItemAtIndex:i];
        }
    }
}


#pragma mark -
#pragma mark FUTabControllerNotifcations

- (void)tabControllerProgressDidChange:(NSNotification *)n {
    if (0 == ++changeCount % 3) { // only update web image every third notification
        NSInteger i = [[[n userInfo] objectForKey:@"FUIndex"] integerValue];
        [self updateImageBrowserItemAtIndex:i];
    }
}


- (void)tabControllerDidFinishLoad:(NSNotification *)n {
    NSInteger i = [[[n userInfo] objectForKey:@"FUIndex"] integerValue];
    [self updateImageBrowserItemAtIndex:i];
    [self performSelector:@selector(updateImageBrowserItemLaterAtIndex:) withObject:[NSNumber numberWithInteger:i] afterDelay:.6];
}


#pragma mark -
#pragma mark Private

- (NSArray *)webViews {
    return [plugInAPI webViewsForWindow:[self.view window]];
}


- (void)updateImageBrowserItemLaterAtIndex:(NSNumber *)indexObj {
    [self updateImageBrowserItemAtIndex:[indexObj integerValue]];
}


- (void)updateImageBrowserItemAtIndex:(NSInteger)i {
    WebView *wv = [[self webViews] objectAtIndex:i];
    
    FUImageBrowserItem *item = [imageBrowserItems objectAtIndex:i];
    [self updateImageBrowserItem:item fromWebView:wv];
    [imageBrowserView reloadData];    
}


- (void)updateImageBrowserItem:(FUImageBrowserItem *)item fromWebView:(WebView *)wv {
    item.imageRepresentation = [self thumbnailFromWebView:wv];
    item.imageTitle = [wv mainFrameTitle];
    item.imageSubtitle = [wv mainFrameURL];
}


- (NSBitmapImageRep *)thumbnailFromWebView:(WebView *)wv {
    return [wv squareBitmapImageRepOfWebContent];
}
         
         
- (void)startObserveringTabController:(id)tc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(tabControllerProgressDidChange:) name:FUTabControllerProgressDidChangeNotification object:tc];
    [nc addObserver:self selector:@selector(tabControllerDidFinishLoad:) name:FUTabControllerDidFinishLoadNotification object:tc];
}


- (void)stopObserveringTabController:(id)tc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:FUTabControllerProgressDidChangeNotification object:tc];
    [nc removeObserver:self name:FUTabControllerDidFinishLoadNotification object:tc];
}

@synthesize imageBrowserView;
@synthesize plugIn;
@synthesize plugInAPI;
@synthesize imageBrowserItems;
@end
