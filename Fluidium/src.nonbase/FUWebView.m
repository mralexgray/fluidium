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

#import "FUWebView.h"
#import "FUApplication.h"
#import "FUUserDefaults.h"
#import "FUWindowController.h"
#import "FUWebPreferences.h"
#import "FUDownloadWindowController.h"
#import "FUUserAgentWindowController.h"
#import "FUNotifications.h"
#import "WebViewPrivate.h"
#import "WebFrameViewPrivate.h"
#import <TDAppKit/TDScrollView.h>

#define VERTICAL_SCROLL_WIDTH 40

//@interface NSObject ()
//- (void)_layoutIfNeeded;
//@end

@interface NSEvent ()
- (CGFloat)magnification;
@end

@interface FUWebView ()
- (void)updateWebPreferences;
- (void)updateUserAgent;
- (void)updateContinuousSpellChecking;
- (void)allowDocumentViewImageUpdate;

- (void)webViewProgressStarted:(NSNotification *)n;
- (void)webViewProgressEstimateChanged:(NSNotification *)n;
- (void)webViewProgressFinished:(NSNotification *)n;    

- (void)updateDocumentViewImageWithAspectRatio:(NSSize)aspectRatio;

@property (nonatomic, readwrite, retain) NSImage *documentViewImage;
@property (nonatomic, retain) NSBitmapImageRep *documentViewBitmap;
@end

@implementation FUWebView

- (id)initWithFrame:(NSRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName {
    if (self = [super initWithFrame:frame frameName:frameName groupName:groupName]) {
        [self setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [self setShouldCloseWithWindow:YES];
        [self setMaintainsBackForwardList:YES];
        [self setDrawsBackground:YES];
        
        [self setDownloadDelegate:[FUDownloadWindowController instance]];
        
        [self updateWebPreferences];
        [self updateUserAgent];
        [self updateContinuousSpellChecking];
        
        //[[[self mainFrame] frameView] _setCustomScrollViewClass:[TDScrollView class]];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(webPreferencesDidChange:) name:FUWebPreferencesDidChangeNotification object:[FUWebPreferences instance]];
        [nc addObserver:self selector:@selector(userAgentStringDidChange:) name:FUUserAgentStringDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(continuousSpellCheckingDidChange:) name:FUContinuousSpellCheckingDidChangeNotification object:nil];

        [nc addObserver:self selector:@selector(webViewProgressStarted:) name:WebViewProgressStartedNotification object:self];
        [nc addObserver:self selector:@selector(webViewProgressEstimateChanged:) name:WebViewProgressEstimateChangedNotification object:self];
        [nc addObserver:self selector:@selector(webViewProgressFinished:) name:WebViewProgressFinishedNotification object:self];
    }
    return self;
}


- (void)dealloc {
#ifdef FUDEBUG
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.documentViewImage = nil;
    self.documentViewBitmap = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUWebView %p %@>", self, [self mainFrameURL]];
}


- (NSString *)applicationNameForUserAgent {
    return [[FUApplication instance] appName];
}


#pragma mark -
#pragma mark Events

- (void)beginGestureWithEvent:(NSEvent *)evt {
    magnified = NO;
}


- (void)endGestureWithEvent:(NSEvent *)evt {
    magnified = YES;
}


- (void)magnifyWithEvent:(NSEvent *)evt {
    if (!magnified) {
        BOOL zoomTextOnly = [[FUUserDefaults instance] zoomTextOnly];
        
        CGFloat magnification = [evt magnification];
        if (magnification > 0) {
            if (zoomTextOnly) {
                [self makeTextLarger:nil];
            } else {
                [self zoomPageIn:nil];
            }
            magnified = YES;
        } else if (magnification < 0) {
            if (zoomTextOnly) {
                [self makeTextSmaller:nil];
            } else {
                [self zoomPageOut:nil];
            }
            magnified = YES;
        }
    }
}


- (void)swipeWithEvent:(NSEvent *)evt {
    CGFloat delta = [evt deltaX];

    FUWindowController *wc = [[self window] windowController];

    if (delta > 0) { // left
        if ([self canGoBack]) {
            if ([self isLoading]) {
                [wc webStopLoading:nil];
            }
            [wc webGoBack:nil];
            return;
        }
    } else if (delta < 0) { // right
        if ([self canGoForward]) {
            if ([self isLoading]) {
                [wc webStopLoading:nil];
            }
            [wc webGoForward:nil];
            return;
        }
    }

    NSBeep();
}


#pragma mark -
#pragma mark Actions

- (IBAction)toggleContinuousSpellChecking:(id)sender {
    BOOL enabled = [[FUUserDefaults instance] continuousSpellCheckingEnabled];
    [[FUUserDefaults instance] setContinuousSpellCheckingEnabled:!enabled];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FUContinuousSpellCheckingDidChangeNotification object:self];
}


#pragma mark -
#pragma mark Notifications

- (void)webPreferencesDidChange:(NSNotification *)n {
    [self updateWebPreferences];
    [self reload:self];
}


- (void)userAgentStringDidChange:(NSNotification *)n {
    [self updateUserAgent];
}


- (void)continuousSpellCheckingDidChange:(NSNotification *)n {
    [self updateContinuousSpellChecking];
}


#pragma mark -
#pragma mark WebViewNotifications

- (void)webViewProgressStarted:(NSNotification *)n {
    documentViewImageNeedsUpdate = YES;
}


- (void)webViewProgressEstimateChanged:(NSNotification *)n {
    if (0 == ++estimateChangeCount % 5) { // only allow update to image on every third progress estimate change
        documentViewImageNeedsUpdate = YES;
    }
}


- (void)webViewProgressFinished:(NSNotification *)n {
    documentViewImageNeedsUpdate = YES;
    [self performSelector:@selector(allowDocumentViewImageUpdate) withObject:nil afterDelay:.3];
}


#pragma mark -
#pragma mark Public

- (NSImage *)documentViewImageWithCurrentAspectRatio {
    return [self documentViewImageWithAspectRatio:[self bounds].size];
}


- (NSImage *)documentViewImageWithAspectRatio:(NSSize)aspectRatio {
    if (documentViewImageNeedsUpdate) {
        
        [self updateDocumentViewImageWithAspectRatio:aspectRatio];
        
        documentViewImageNeedsUpdate = NO;
    }
    
    return documentViewImage;
}


#pragma mark -
#pragma mark Private

- (void)updateWebPreferences {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WebPreferencesChangedNotification object:[self preferences]];
    [self setPreferences:[FUWebPreferences instance]];
}


- (void)updateUserAgent {
    [self setCustomUserAgent:[[FUUserAgentWindowController instance] userAgentString]];
}


- (void)updateContinuousSpellChecking {
    [self setContinuousSpellCheckingEnabled:[[FUUserDefaults instance] continuousSpellCheckingEnabled]];
}


- (void)updateDocumentViewImageWithAspectRatio:(NSSize)aspectRatio {
    NSView *docView = [[[self mainFrame] frameView] documentView];
    
    NSRect docFrame = [docView frame];
    if (NSIsEmptyRect(docFrame)) {
        documentViewImageNeedsUpdate = YES;
        return;
    }

//    if ([docView respondsToSelector:@selector(_layoutIfNeeded)]) {
//        [docView _layoutIfNeeded];
//    }
    
    CGFloat ratio = 0;
    NSRect imageFrame = NSZeroRect;
    if (aspectRatio.width > aspectRatio.height) {
        ratio = aspectRatio.height / aspectRatio.width;
        imageFrame = NSMakeRect(0, 0, docFrame.size.width, floor(docFrame.size.width * ratio));
    } else {
        ratio = aspectRatio.width / aspectRatio.height;
        imageFrame = NSMakeRect(0, 0, floor(docFrame.size.height * ratio), docFrame.size.width);
    }
    
    if (!documentViewBitmap || !NSEqualSizes([documentViewBitmap size], docFrame.size)) {
        //NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!! had to make a new bitmap");
        self.documentViewBitmap = [docView bitmapImageRepForCachingDisplayInRect:docFrame];
    } else {
        //NSLog(@"didnt have to make a new bitmap. reusing");
    }
    
    [docView cacheDisplayInRect:imageFrame toBitmapImageRep:documentViewBitmap];
    
    
    ///////
    CGImageRef cgImg = CGImageCreateWithImageInRect([documentViewBitmap CGImage], NSRectToCGRect(imageFrame));
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:cgImg] autorelease];
    CGImageRelease(cgImg);
    self.documentViewImage = [[[NSImage alloc] initWithSize:imageFrame.size] autorelease];
    [documentViewImage addRepresentation:bitmap];
    //////
    
    
//    NSLog(@"docFrame: %@", NSStringFromRect(docFrame));
//    NSLog(@"imageFrame: %@", NSStringFromRect(imageFrame));
//    
//    NSLog(@"bitmapSize: %@", NSStringFromSize([documentViewBitmap size]));
//    NSLog(@"imageSize: %@", NSStringFromSize([documentViewImage size]));
    
    //    [docView setNeedsDisplay:YES];
}


- (NSImage *)entireDocumentImage {
    NSView *docView = [[[self mainFrame] frameView] documentView];
    
    NSRect docFrame = [docView frame];
    if (NSIsEmptyRect(docFrame)) {
        return nil;
    }
    
    NSRect imageFrame = docFrame;
//    if (aspectRatio.width > aspectRatio.height) {
//        ratio = aspectRatio.height / aspectRatio.width;
//        imageFrame = NSMakeRect(0, 0, docFrame.size.width, floor(docFrame.size.width * ratio));
//    } else {
//        ratio = aspectRatio.width / aspectRatio.height;
//        imageFrame = NSMakeRect(0, 0, floor(docFrame.size.height * ratio), docFrame.size.width);
//    }
    
    NSBitmapImageRep *bitmap = [docView bitmapImageRepForCachingDisplayInRect:docFrame];
    [docView cacheDisplayInRect:imageFrame toBitmapImageRep:bitmap];
    
    
    ///////
    CGImageRef cgImg = CGImageCreateWithImageInRect([bitmap CGImage], NSRectToCGRect(imageFrame));
    bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:cgImg] autorelease];
    CGImageRelease(cgImg);
    NSImage *result = [[[NSImage alloc] initWithSize:imageFrame.size] autorelease];
    [result addRepresentation:bitmap];
    //////
    
    return result;
    
    
    //    NSLog(@"docFrame: %@", NSStringFromRect(docFrame));
    //    NSLog(@"imageFrame: %@", NSStringFromRect(imageFrame));
    //    
    //    NSLog(@"bitmapSize: %@", NSStringFromSize([documentViewBitmap size]));
    //    NSLog(@"imageSize: %@", NSStringFromSize([documentViewImage size]));
    
    //    [docView setNeedsDisplay:YES];
}


- (void)allowDocumentViewImageUpdate {
    documentViewImageNeedsUpdate = YES;
}

@synthesize documentViewImage;
@synthesize documentViewBitmap;
@end
