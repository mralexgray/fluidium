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

#import "FUBookmarkBarButton.h"
#import "FUBookmarkBar.h"
#import "FUBookmark.h"
#import "FUBookmarkBarButtonCell.h"
#import "FUBookmarkController.h"
#import "FUUserDefaults.h"
#import "WebIconDatabase.h"
#import "WebIconDatabase+FUAdditions.h"
#import <WebKit/WebKit.h>

#define ICON_SIDE 16

@interface NSToolbarPoofAnimator
+ (void)runPoofAtPoint:(NSPoint)p;
@end

@interface FUBookmarkBarButton ()
- (void)killTimer;
- (void)displayMenu:(NSTimer *)t;

@property (nonatomic, retain) NSTimer *timer;
@end

@implementation FUBookmarkBarButton

+ (Class)cellClass {
    return [FUBookmarkBarButtonCell class];
}


- (id)initWithBookmarkBar:(FUBookmarkBar *)bar bookmark:(FUBookmark *)bmark {
    if (self = [super init]) {
        self.bookmarkBar = bar;
        self.bookmark = bmark;

        if ([[FUUserDefaults instance] bookmarkBarShowsFavicons]) {
            [self setImagePosition:NSImageLeft];
            [self setImage:[[WebIconDatabase sharedIconDatabase] faviconForURL:bookmark.content]];
        }
        
        [self setTitle:bookmark.title];
        [self setBezelStyle:NSRecessedBezelStyle];
        [self setShowsBorderOnlyWhileMouseInside:YES];
    }
    return self;
}


- (void)dealloc {
    self.bookmarkBar = nil;
    self.bookmark = nil;
    [self killTimer];
    [super dealloc];
}


- (void)killTimer {
    if (timer) {
        [timer invalidate];
        self.timer = nil;
    }
}


#pragma mark -
#pragma mark Left Click

- (void)mouseDown:(NSEvent *)evt {
    [[self cell] setHighlighted:YES];
    
    BOOL keepOn = YES;
    NSPoint p = [evt locationInWindow];
    NSInteger radius = 20;
    NSRect r = NSMakeRect(p.x - radius, p.y - radius, radius * 2, radius * 2);
    
    while (keepOn) {
        evt = [[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];
        
        switch ([evt type]) {
            case NSLeftMouseDragged:
                if (NSPointInRect([evt locationInWindow], r)) {
                    break;
                }
                [self mouseDragged:evt];
                keepOn = NO;
                break;
            case NSLeftMouseUp:
                keepOn = NO;
                [super mouseDown:evt];
                break;
            default:
                break;
        }
    }
    return;
}


- (void)mouseDragged:(NSEvent *)evt {    
    [bookmarkBar startedDraggingButton:self];

    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [bookmark writeWebURLsToPasteboard:pboard];
    
    NSImage *dragImage = [[WebIconDatabase sharedIconDatabase] defaultFavicon];
    NSPoint dragPosition = [self convertPoint:[evt locationInWindow] fromView:nil];

    CGFloat delta = ICON_SIDE / 2;
    dragPosition.x -= delta;
    dragPosition.y += delta;

    [self dragImage:dragImage
                 at:dragPosition
             offset:NSZeroSize
              event:evt
         pasteboard:pboard
             source:self
          slideBack:NO];
}


- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return (NSDragOperationMove|NSDragOperationDelete);
}


- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)endPoint operation:(NSDragOperation)op {
    NSPoint p = [[bookmarkBar window] convertScreenToBase:endPoint];
    CGFloat delta = ICON_SIDE / 2;
    p.x += delta;
    p.y += delta;

    if (!NSPointInRect(p, [bookmarkBar frame])) {
        endPoint.x += delta;
        endPoint.y += delta;
        [NSToolbarPoofAnimator runPoofAtPoint:endPoint];
    }

    [bookmarkBar finishedDraggingButton];
}


#pragma mark -
#pragma mark Right Click

- (void)rightMouseDown:(NSEvent *)evt { 
    [self highlight:NO];
    [self setImage:[NSImage imageNamed:@"OverflowButtonPressed"]];
    
    self.timer = [NSTimer timerWithTimeInterval:0 
                                         target:self 
                                       selector:@selector(displayMenu:) 
                                       userInfo:evt 
                                        repeats:NO];
    
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
} 


- (void)displayMenu:(NSTimer *)t {
    NSEvent *evt = [timer userInfo];
    
    NSEvent *click = [NSEvent mouseEventWithType:[evt type] 
                                        location:[evt locationInWindow]
                                   modifierFlags:[evt modifierFlags] 
                                       timestamp:[evt timestamp] 
                                    windowNumber:[evt windowNumber] 
                                         context:[evt context]
                                     eventNumber:[evt eventNumber] 
                                      clickCount:[evt clickCount] 
                                        pressure:[evt pressure]]; 
    
    NSMenu *menu = [[FUBookmarkController instance] contextMenuForBookmark:bookmark];
    [NSMenu popUpContextMenu:menu withEvent:click forView:self];
    [self killTimer];
}

@synthesize hovered;
@synthesize bookmarkBar;
@synthesize bookmark;
@synthesize timer;
@end
