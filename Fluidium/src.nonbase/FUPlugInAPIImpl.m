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

#import "FUPlugInAPIImpl.h"
#import "FUPlugInController.h"
#import "FUWindowController.h"
#import "FUDocumentController.h"
#import "FUTabController.h"
#import "FUApplication.h"
#import "FURecentURLController.h"
#import "FUDownloadWindowController.h"
#import "FUUserAgentWindowController.h"
#import "FUWindow.h"
#import "FUWebView.h"
#import "FUPlugInWrapper.h"
#import "FUPlugInAPI.h"
#import <WebKit/WebKit.h>

@interface FUPlugInAPIImpl ()
- (FUWindowController *)windowControllerForWindow:(NSWindow *)win;

@property (nonatomic, copy, readwrite) NSString *version;
@property (nonatomic, copy, readwrite) NSString *plugInSupportDirPath;
@end

@implementation FUPlugInAPIImpl

- (id)init {
    if (self = [super init]) {
        self.version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        self.plugInSupportDirPath = [[[FUApplication instance] ssbSupportDirPath] stringByAppendingPathComponent:@"PlugIn Support"];
        [[NSFileManager defaultManager] createDirectoryAtPath:plugInSupportDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}


- (void)dealloc {
    self.version = nil;
    self.plugInSupportDirPath = nil;
    [super dealloc];
}


- (NSString *)appName {
    return [[FUApplication instance] appName];
}


- (NSString *)defaultUserAgentString {
    return [[FUUserAgentWindowController instance] defaultUserAgentString];
}


- (NSArray *)allUserAgentStrings {
    return [[FUUserAgentWindowController instance] allUserAgentStrings];
}


- (NSUInteger)viewPlacementForPlugInIdentifier:(NSString *)s {
    FUPlugInWrapper *wrap = [[FUPlugInController instance] plugInWrapperForIdentifier:s];
    return [wrap viewPlacementMask];
}


- (NSViewController *)plugInViewControllerForPlugInIdentifier:(NSString *)s inWindow:(NSWindow *)win {
    FUPlugInWrapper *wrap = [[FUPlugInController instance] plugInWrapperForIdentifier:s];
    return [wrap plugInViewControllerForWindowNumber:[win windowNumber]];
}


- (BOOL)isFullScreen {
    return [[FUApplication instance] isFullScreen];
}


- (WebView *)frontWebView {
    return [[FUDocumentController instance] frontWebView];
}


- (WebView *)selectedWebViewForWindow:(NSWindow *)win {
    if (![win isKindOfClass:[FUWindow class]]) {
        return nil;
    }
    
    FUWindowController *wc = [self windowControllerForWindow:win];
    return [[wc selectedTabController] webView];
}


- (NSArray *)webViewsForWindow:(NSWindow *)win {
    if (![win isKindOfClass:[FUWindow class]]) {
        return nil;
    }

    return [[self windowControllerForWindow:win] webViews];
}


- (NSArray *)webViewsForDrawer:(NSDrawer *)drawer {
    NSWindow *win = [drawer parentWindow];
    return [self webViewsForWindow:win];
}


- (WebView *)newWebViewForPlugIn:(FUPlugIn *)plugIn {
    return [[FUWebView alloc] initWithFrame:NSZeroRect];
}


- (void)loadURL:(NSString *)URLString {
    [[FUDocumentController instance] loadURL:URLString];
}


- (void)loadURL:(NSString *)URLString destinationType:(FUPlugInDestinationType)type {
    [[FUDocumentController instance] loadURL:URLString destinationType:type];
}


- (void)loadURL:(NSString *)URLString destinationType:(FUPlugInDestinationType)type inForeground:(BOOL)inForeground {
    [[FUDocumentController instance] loadURL:URLString destinationType:type inForeground:inForeground];
}


- (void)downloadRequest:(NSURLRequest *)req directory:(NSString *)dirPath filename:(NSString *)filename {
    [[FUDownloadWindowController instance] downloadRequest:req directory:dirPath filename:filename];
}


- (void)showStatusText:(NSString *)statusText {
    [[[FUDocumentController instance] frontTabController] setStatusText:statusText];
}


- (void)addRecentURL:(NSString *)URLString {
    [[FURecentURLController instance] addRecentURL:URLString];
}


- (void)addMatchingRecentURL:(NSString *)URLString {
    [[FURecentURLController instance] addMatchingRecentURL:URLString];
}


- (void)removeRecentURL:(NSString *)URLString {
    [[FURecentURLController instance] removeRecentURL:URLString];
}


- (NSArray *)recentURLs {
    return [[FURecentURLController instance] recentURLs];
}


- (NSArray *)matchingRecentURLs {
    return [[FURecentURLController instance] matchingRecentURLs];
}


- (void)resetRecentURLs {
    [[FURecentURLController instance] resetRecentURLs];
}


- (void)resetMatchingRecentURLs {
    [[FURecentURLController instance] resetMatchingRecentURLs];
}


- (void)showPreferencePaneForIdentifier:(NSString *)s {
    [[FUApplication instance] showPreferencePaneForIdentifier:s];
}


#pragma mark -
#pragma mark Private

- (FUWindowController *)windowControllerForWindow:(NSWindow *)win {
    if ([win isKindOfClass:[FUWindow class]]) {
        return [win windowController];
    } else {
        return [[FUDocumentController instance] frontWindowController];
    }
}

@synthesize version;
@synthesize plugInSupportDirPath;
@end
