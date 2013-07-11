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

#import "FUUserscriptController.h"
#import "FUWindowController.h"
#import "FUTabController.h"
#import "FUWebView.h"
#import "FUApplication.h"
#import "FUWildcardPattern.h"
#import "FUUtils.h"
#import "FUNotifications.h"
#import <WebKit/WebKit.h>

#define KEY_USERSCRIPT_SRC @"userscriptSrc"
#define KEY_TABCONTROLLER @"tabController"

@interface FUUserscriptController ()
- (void)loadUserscripts;
- (NSString *)userscriptSourceForURLString:(NSString *)URLString;
- (void)executeUserscriptLater:(NSMutableDictionary *)args;
- (void)executeUserscript:(NSString *)userscriptSrc inWebView:(WebView *)wv;
@end

@implementation FUUserscriptController

+ (FUUserscriptController *)instance {
    static FUUserscriptController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUUserscriptController alloc] init];
        }
    }
    return instance;
}


- (id)init {
    if (self = [super init]) {
        [self loadUserscripts];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(tabControllerDidLoadDOMContent:) name:FUTabControllerDidLoadDOMContentNotification object:nil];
    }
    return self;
}


- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.userscripts = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Public

- (void)save {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSArray arrayWithArray:userscripts] forKey:@"FUUserscripts"];
    NSURL *furl = [NSURL fileURLWithPath:[[FUApplication instance] userscriptFilePath]];
    [dict writeToURL:furl atomically:YES];    
}


#pragma mark -
#pragma mark Notifications

- (void)tabControllerDidLoadDOMContent:(NSNotification *)n {
    FUTabController *tc = [n object];
    WebView *wv = [tc webView];
    NSString *userscriptSrc = [self userscriptSourceForURLString:[wv mainFrameURL]];
    
    if (![userscriptSrc length]) {
        return;
    }
    
    NSMutableDictionary *args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 userscriptSrc, KEY_USERSCRIPT_SRC,
                                 [n object], KEY_TABCONTROLLER,
                                 nil];

    [self performSelector:@selector(executeUserscriptLater:) withObject:args afterDelay:0];
}


#pragma mark -
#pragma mark Private

- (void)loadUserscripts {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[FUApplication instance] userscriptFilePath]];
    self.userscripts = [NSMutableArray arrayWithArray:[dict objectForKey:@"FUUserscripts"]];
}


static NSInteger FUSortMatchedUserscripts(NSDictionary *a, NSDictionary *b, void *ctx) {
    NSInteger lenA = [(NSString *)[a objectForKey:@"URLPattern"] length];
    NSInteger lenB = [(NSString *)[b objectForKey:@"URLPattern"] length];
    
    if (lenA > lenB) {
        return NSOrderedAscending;
    } else if (lenB > lenA) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}


- (NSString *)userscriptSourceForURLString:(NSString *)URLString {
    if (![userscripts count] || ![URLString length]) return nil;
    
    NSMutableArray *matchedUserscripts = [NSMutableArray array];
    
    for (id userscriptDict in userscripts) {
        FUWildcardPattern *pattern = [FUWildcardPattern patternWithString:[userscriptDict objectForKey:@"URLPattern"]];
        if ([pattern isMatch:URLString]) {
            if ([[userscriptDict objectForKey:@"enabled"] boolValue]) {
                [matchedUserscripts addObject:userscriptDict];
            }
        }
    }
    
    if ([matchedUserscripts count]) {
        [matchedUserscripts sortUsingFunction:FUSortMatchedUserscripts context:NULL];
        return [[matchedUserscripts objectAtIndex:0] objectForKey:@"source"];
    } else {
        return nil;
    }
}


- (void)executeUserscriptLater:(NSMutableDictionary *)args {
    WebView *wv = [[args objectForKey:KEY_TABCONTROLLER] webView];
    NSMutableString *script = [NSMutableString string];
    [script appendString:@"(function() {\n\treturn function() {\n\t\t"];
    [script appendString:[args objectForKey:KEY_USERSCRIPT_SRC]];
    [script appendString:@"\n\t}\n})();\n"];
    [self executeUserscript:script inWebView:wv];
}


- (void)executeUserscript:(NSString *)userscriptSrc inWebView:(WebView *)wv {
    WebScriptObject *func = [[wv windowScriptObject] evaluateWebScript:userscriptSrc];
    if (!func || FUIsWebUndefined(func)) {
        return;
    }
    
    WebScriptObject *jsThis = [func evaluateWebScript:@"this"];
    if (!jsThis || FUIsWebUndefined(jsThis)) {
        return;
    } else {
        DOMDocument *doc = [wv mainFrameDocument];
        [func callWebScriptMethod:@"call" withArguments:[NSArray arrayWithObjects:jsThis, doc, nil]];
    }
}

@synthesize userscripts;
@end
