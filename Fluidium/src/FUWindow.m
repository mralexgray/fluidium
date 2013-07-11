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

#import "FUWindow.h"
#import "FUWindowController.h"
#import "FUPlugInController.h"
#import "FUPlugInWrapper.h"
#import "FUUserDefaults.h"
#import "FUNotifications.h"
#import "FUApplication.h"
#import <TDAppKit/NSEvent+TDAdditions.h>

#define CLOSE_CURLY 30
#define OPEN_CURLY 33
#define LEFT_ARROW 123
#define RIGHT_ARROW 124   

@interface FUWindow ()
- (BOOL)handleHideFindPanel:(NSEvent *)evt;
- (BOOL)handleNextPrevTab:(NSEvent *)evt;
- (BOOL)handleGoBackForward:(NSEvent *)evt;
- (BOOL)hideFindPanel;
- (void)allowBrowsaPlugInsToHandleMouseMoved:(NSEvent *)evt;
- (void)sendMouseMovedEvent:(NSEvent *)evt toPlugInWithIdentifier:(NSString *)identifier;
@end

@implementation FUWindow

- (id)initWithContentRect:(NSRect)rect styleMask:(NSUInteger)style backing:(NSBackingStoreType)type defer:(BOOL)flag {
    if (self = [super initWithContentRect:rect styleMask:style backing:type defer:flag]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(spacesBehaviorDidChange:) name:FUSpacesBehaviorDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(windowLevelDidChange:) name:FUWindowLevelDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(windowsHaveShadowDidChange:) name:FUWindowsHaveShadowDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(windowOpacityDidChange:) name:FUWindowOpacityDidChangeNotification object:nil];

        [self spacesBehaviorDidChange:nil];
        [self windowLevelDidChange:nil];
        [self windowsHaveShadowDidChange:nil];
        [self windowOpacityDidChange:nil];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.comboField = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUWindow %p %ld>", self, [self windowNumber]];
}


- (BOOL)acceptsFirstResponder {
    return YES;
}


// this is necessary to prevent NSBeep() on every key press in the findPanel
- (BOOL)makeFirstResponder:(NSResponder *)resp {
    FUWindowController *wc = [self windowController];
    if (wc.isTypingInFindPanel) {
        if ([[resp className] isEqualToString:@"WebHTMLView"]) {
            return NO;
        }
    }
    return [super makeFirstResponder:resp];
}


// override with a noop. that supresses NSBeep for keyDown events not handled by webview
- (void)keyDown:(NSEvent *)evt {
}


- (void)mouseMoved:(NSEvent *)evt {
    [super mouseMoved:evt];

    // would be nice to remove this hack. but necessary to get 'navbar appears when moused over' to work in all cases
    [self allowBrowsaPlugInsToHandleMouseMoved:evt];
}


- (void)sendEvent:(NSEvent *)evt {
    
    if ([evt isMouseDown] || [evt isMouseMoved]) {
        [self hideFindPanel];
    }

    else if ([evt isKeyUpOrDown]) {
        // handle closing the search panel via <ESC> key
        if ([self handleHideFindPanel:evt]) {
            return;
        }
                                                   
        // also handle ⌘-{ and ⌘-} tab switching
        else if ([self handleNextPrevTab:evt]) {
            return;
        }
        
        // also handle ⌘-← and ⌘-→ back / fwd to make sure it is routed thru script recording
        else if ([self handleGoBackForward:evt]) {
            return;
        }        
    }
    
//    else if (NSLeftMouseDragged == [evt type]) {
//        if (
//    }
    
    [super sendEvent:evt];
}


#pragma mark -
#pragma mark Actions

- (IBAction)performClose:(id)sender {
    [[self windowController] performClose:sender];
}


- (IBAction)forcePerformClose:(id)sender {
    [super performClose:sender];
}


#pragma mark -
#pragma mark Notifications

- (void)spacesBehaviorDidChange:(NSNotification *)n {
    NSInteger spacesBehavior = [[FUUserDefaults instance] spacesBehavior];

    NSUInteger flag = NSWindowCollectionBehaviorDefault;
    if (1 == spacesBehavior) {
        flag = NSWindowCollectionBehaviorCanJoinAllSpaces;
    } else if (2 == spacesBehavior) {
        flag = NSWindowCollectionBehaviorMoveToActiveSpace;
    }
    
    [self setCollectionBehavior:flag];
}


- (void)windowLevelDidChange:(NSNotification *)n {
    NSInteger level = [[FUUserDefaults instance] windowLevel];
    
    if ([[FUApplication instance] isFullScreen]) {
        level = FUWindowLevelNormal;
    }
    
    NSUInteger flag = NSNormalWindowLevel;
    
    if (FUWindowLevelFloating == level) {
        flag = NSFloatingWindowLevel;
    } else if (FUWindowLevelBelowDesktop == level) {
        BOOL appearInAllSpaces = [[FUUserDefaults instance] spacesBehavior];
        if (appearInAllSpaces) {
            flag = CGWindowLevelForKey(kCGDesktopWindowLevelKey); // below dtop
        } else {
            flag = CGWindowLevelForKey(kCGBackstopMenuLevelKey); // above dtop
        }
    }
    
    [self setLevel:flag];
}


- (void)windowOpacityDidChange:(NSNotification *)n {
	[self setAlphaValue:[[FUUserDefaults instance] windowOpacity]];
}


- (void)windowsHaveShadowDidChange:(NSNotification *)n {
	[self setHasShadow:[[FUUserDefaults instance] windowsHaveShadow]];
	[self invalidateShadow];
}


#pragma mark -
#pragma mark Private

- (BOOL)handleHideFindPanel:(NSEvent *)evt {
    if ([evt isEscKeyPressed]) {
        return [self hideFindPanel];
    } else {
        return NO;
    }
}


- (BOOL)handleNextPrevTab:(NSEvent *)evt {
    if ([evt isCommandKeyPressed]) {
        NSInteger keyCode = [evt keyCode];
        if (CLOSE_CURLY == keyCode || OPEN_CURLY == keyCode) {
            FUWindowController *wc = [self windowController];
            if (CLOSE_CURLY == keyCode) {
                [wc selectNextTab:self];
            } else if (OPEN_CURLY == keyCode) {
                [wc selectPreviousTab:self];
            }
            return YES;
        }
    }
    return NO;
}


- (BOOL)handleGoBackForward:(NSEvent *)evt {
    if ([evt isCommandKeyPressed]) {
        NSInteger keyCode = [evt keyCode];
        if (LEFT_ARROW == keyCode || RIGHT_ARROW == keyCode) {

            // don't steal the event from text fields/views
            id resp = [self firstResponder];
            if ([resp isKindOfClass:[NSTextField class]] || [resp isKindOfClass:[NSText class]]) {
                return NO;
            }
            
            FUWindowController *wc = [self windowController];
            if (LEFT_ARROW == keyCode) {
                [wc webGoBack:self];
            } else if (RIGHT_ARROW == keyCode) {
                [wc webGoForward:self];
            }
            return YES;
        }
    }
    return NO;
}


- (BOOL)hideFindPanel {
    FUWindowController *wc = [self windowController];
    if ([wc isFindPanelVisible]) {
        [wc hideFindPanel:self];
        return YES;
    } else {
        return NO;
    }
}


- (void)allowBrowsaPlugInsToHandleMouseMoved:(NSEvent *)evt {
    NSInteger i = 0;
    NSInteger c = [[FUUserDefaults instance] numberOfBrowsaPlugIns];
    for ( ; i < c; i++) {
        NSString *identifier = [NSString stringWithFormat:@"com.fluidapp.BrowsaPlugIn%ld", i];
        [self sendMouseMovedEvent:evt toPlugInWithIdentifier:identifier];
    }
}


- (void)sendMouseMovedEvent:(NSEvent *)evt toPlugInWithIdentifier:(NSString *)identifier {
    FUPlugInWrapper *wrap = [[FUPlugInController instance] plugInWrapperForIdentifier:identifier];
    NSInteger num = [self windowNumber];
    if ([wrap isVisibleInWindowNumber:num]) {
        NSViewController *vc = [wrap plugInViewControllerForWindowNumber:num];
        [vc.view mouseMoved:evt];
    }
}


- (NSText *)fieldEditor:(BOOL)createWhenNeeded forObject:(id)obj {
    if (obj == comboField) {
        return (NSTextView *)comboField.fieldEditor;
    } else {
        return [super fieldEditor:createWhenNeeded forObject:obj];
    }
}

@synthesize comboField;
@end
