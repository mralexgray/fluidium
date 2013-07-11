//  Copyright 2010 Todd Ditchendorf
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

#import "FUDocument+Scripting.h"
#import "FUWindowController+Scripting.h"
#import "FUTabController+Scripting.h"
#import "FUWindowController.h"
#import "FUTabController.h"
#import <TDAppKit/NSAppleEventDescriptor+TDAdditions.h>

#define DEFAULT_DELAY 1.0

@interface FUWindowController ()
- (void)closeWindow;
//- (void)script_setSelectedTabIndex:(NSInteger)i;

@property (nonatomic, retain, readwrite) FUTabController *selectedTabController;
@end

@interface FUTabController ()
@property (nonatomic, assign, readwrite) FUWindowController *windowController; // weak ref
@end

@implementation FUDocument (Scripting)

#pragma mark -
#pragma mark NSObjectSpecifiers

- (FourCharCode)classCode {
    return 'fDoc';
}


- (NSScriptObjectSpecifier *)objectSpecifier {
    NSUInteger i = [[NSApp orderedDocuments] indexOfObject:self];
    
    if (NSNotFound == i) {
        return nil;
    } else {
        NSScriptClassDescription *cls = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
        return [[[NSIndexSpecifier alloc] initWithContainerClassDescription:cls containerSpecifier:nil key:@"orderedDocuments" index:i] autorelease];
    }
}


#pragma mark -
#pragma mark Properties

- (NSArray *)orderedTabControllers {
    NSTabView *tabView = [windowController tabView];
    NSMutableArray *tabs = [NSMutableArray arrayWithCapacity:[tabView numberOfTabViewItems]];
    for (NSTabViewItem *tabItem in [tabView tabViewItems]) {
        [tabs addObject:[tabItem identifier]];
    }
    return [[tabs copy] autorelease];
}


- (NSString *)selectedTabURLString {
    return [[self selectedTabController] URLString];
}



- (NSString *)selectedDocumentSource {
    return [[self selectedTabController] documentSource];
}


- (BOOL)isSelectedTabProcessing {
    return [[self selectedTabController] isProcessing];
}


//- (NSUInteger)selectedTabIndex {
//    return [windowController selectedTabIndex] + 1;
//}
//
//
//- (void)setSelectedTabIndex:(NSUInteger)i {
//    i = i - 1; // account for 1-based AppleScript indexing
//    
//    // delay the command a bit 
//    FUTabController *tc = [windowController tabControllerAtIndex:i];
//    [tc suspendCommand:[NSScriptCommand currentCommand]];
//    [tc resumeSuspendedCommandAfterDelay:DEFAULT_DELAY];
//    
//    [windowController script_setSelectedTabIndex:i];
//}


- (FUTabController *)selectedTabController {
    return [windowController selectedTabController];
}


- (void)setSelectedTabController:(FUTabController *)tc {
    [windowController script_selectTabController:tc];
}


#pragma mark -
#pragma mark Commands

- (id)handleCreateCommand:(NSCreateCommand *)cmd {
    NSDictionary *props = [[cmd evaluatedArguments] objectForKey:@"KeyDictionary"];
    
    BOOL isSelected = YES;
    if (props) {
        id obj = [props objectForKey:@"isSelected"];
        if (obj) {
            isSelected = [obj boolValue];
        }
    }
    
    FUTabController *tc = nil;

    if (isSelected) {
        [windowController script_newTab:nil];
        tc = [windowController selectedTabController];
    } else {
        [windowController script_newBackgroundTab:nil];
        tc = [windowController lastTabController];
    }
    
    return [tc objectSpecifier];
}


- (id)handleLoadURLCommand:(NSScriptCommand *)cmd {
    // don't call -[FUBaseScriptCommand targetTabController] here as it will route around the shortcut handling mechanism if there's no explicit tabController arg
    FUTabController *tc = [[cmd evaluatedArguments] objectForKey:@"tabController"];
    if (!tc) {
        tc = [windowController selectedTabController];
    }
    return [tc handleLoadURLCommand:cmd];
//    
//    [tc suspendExecutionUntilProgressFinishedWithCommand:cmd];
//    
//    // dont send this straight to the tabController. that would circumvent the shortcut handling mechanism
//    // which only works from the locationCombox. should we change that? for now, i say no.
//    NSString *s = [cmd directParameter];
//    [windowController.locationComboBox setStringValue:s];
//    [windowController noscript_goToLocation:nil];
//    //[windowController goToLocation:nil];
//    return nil;
}


- (id)handleDoJavaScriptCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleDoJavaScriptCommand:cmd];
}


- (id)handleGoBackCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleGoBackCommand:cmd];
//    if ([[[windowController selectedTabController] webView] canGoBack]) {
//        [windowController script_webGoBack:nil];
//    } else {
//        [self setScriptErrorNumber:47];
//        [self setScriptErrorString:@"The selected tab cannot currently go back."];
//    }
//    return nil;
}


- (id)handleGoForwardCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleGoForwardCommand:cmd];
//    if ([[[windowController selectedTabController] webView] canGoForward]) {
//        [windowController script_webGoForward:nil];
//    } else {
//        [self setScriptErrorNumber:47];
//        [self setScriptErrorString:@"The selected tab cannot currently go forward."];
//    }
//    
//    return nil;
}


- (id)handleReloadCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleReloadCommand:cmd];
//    if ([[[windowController selectedTabController] webView] canReload]) {
//        [windowController script_webReload:nil];
//    } else {
//        [self setScriptErrorNumber:47];
//        [self setScriptErrorString:@"The selected tab cannot currently reload."];
//    }
//    return nil;
}


- (id)handleStopLoadingCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleStopLoadingCommand:cmd];
//    [windowController script_webStopLoading:nil];
//    return nil;
}


- (id)handleGoHomeCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleGoHomeCommand:cmd];
//    [windowController script_webGoHome:nil];
//    return nil;
}


- (id)handleZoomInCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleZoomInCommand:cmd];
//    [windowController script_zoomIn:nil];
//    return nil;
}


- (id)handleZoomOutCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleZoomOutCommand:cmd];
//    [windowController script_zoomOut:nil];
//    return nil;
}


- (id)handleActualSizeCommand:(NSScriptCommand *)cmd {
    return [[windowController selectedTabController] handleActualSizeCommand:cmd];
//    [windowController script_actualSize:nil];
//    return nil;
}

@end
