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

#import "FUBookmarkBar.h"
#import "FUBookmarkBarButton.h"
#import "FUBookmarkButtonSeparator.h"
#import "FUBookmarkBarOverflowButton.h"
#import "FUBookmarkController.h"
#import "FUBookmarkWindowController.h"
#import "FUBookmark.h"
#import "FUDocumentController.h"
#import "FUWindowController.h"
#import "FUUtils.h"
#import "FUNotifications.h"
#import "NSPasteboard+FUAdditions.h"
#import "WebURLsWithTitles.h"

#define BUTTON_SPACING 4
#define BUTTON_MARGIN_LEFT 2
#define BUTTON_MAX_WIDTH 180
#define SEPARATOR_MIN_X 3

@interface FUBookmarkBar (Private)
- (NSButton *)newButtonWithBookmark:(FUBookmark *)bmark;
- (void)performActionForButton:(id)sender;
- (void)updateSeparatorForPoint:(NSPoint)p;
- (FUBookmarkBarButton *)buttonAtX:(CGFloat)x;
- (void)addButtonForBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i;
- (void)addBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i;
- (void)createOverflowMenu;
- (void)layoutButtons;
- (void)removeAllButtons;
- (void)postBookmarksDidChangeNotification;
@end

@implementation FUBookmarkBar

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {        
        self.overflowButton = [[[FUBookmarkBarOverflowButton alloc] init] autorelease];
        [overflowButton setTarget:self];

        self.separator = [[[FUBookmarkButtonSeparator alloc] init] autorelease];
        self.buttons = [NSMutableArray array];
                
        NSArray *types = [NSArray arrayWithObjects:WebURLsWithTitlesPboardType, NSURLPboardType, nil];
        [self registerForDraggedTypes:types];
        [self createOverflowMenu];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.separator = nil;
    self.buttons = nil;
    self.overflowButton = nil;
    self.overflowMenu = nil;
    self.draggingButton = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    [super awakeFromNib];
    [self bookmarksDidChange:nil];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(bookmarksDidChange:) name:FUBookmarksDidChangeNotification object:nil];
//    [nc addObserver:self selector:@selector(windowDidBecomeMain:) name:NSWindowDidBecomeMainNotification object:[self window]];
//    [nc addObserver:self selector:@selector(windowDidResignMain:) name:NSWindowDidResignMainNotification object:[self window]];    

    NSColor *bgColor = FUMainTabBackgroundColor();
    self.mainBgGradient = [[[NSGradient alloc] initWithStartingColor:[bgColor colorWithAlphaComponent:.65] endingColor:bgColor] autorelease];
    bgColor = FUNonMainTabBackgroundColor();
    self.nonMainBgGradient = [[[NSGradient alloc] initWithStartingColor:[bgColor colorWithAlphaComponent:.45] endingColor:bgColor] autorelease];
    self.mainTopBorderColor = [NSColor colorWithDeviceWhite:.4 alpha:1];
    self.nonMainTopBorderColor = [NSColor colorWithDeviceWhite:.64 alpha:1];
    self.mainTopBevelColor = [NSColor colorWithDeviceWhite:.75 alpha:1];
    self.nonMainTopBevelColor = [NSColor colorWithDeviceWhite:.9 alpha:1];
    self.mainBottomBevelColor = nil;
    self.nonMainBottomBevelColor = nil;
}


- (BOOL)shouldDrawTopBorder {
    return YES; //[[[self window] toolbar] isVisible];
}


- (void)mouseDown:(NSEvent *)evt {
    if ([evt clickCount] > 1) {
        [[FUBookmarkWindowController instance] showWindow:self];
    } else {
        [super mouseDown:evt];
    }
}


- (void)rightMouseDown:(NSEvent *)evt {
    [super rightMouseDown:evt];
}


- (void)otherMouseDown:(NSEvent *)evt {
    NSPoint p = [self convertPointFromBase:evt.locationInWindow];
    FUBookmarkBarButton *button = [self buttonAtX:p.x];
    if (button) {
        [self performActionForButton:button];
    }
    [super otherMouseDown:evt];
}


#pragma mark -
#pragma mark Notifications

//- (void)windowDidBecomeMain:(NSNotification *)n {
//    [self setNeedsDisplay:YES];
//}
//
//
//- (void)windowDidResignMain:(NSNotification *)n {
//    [self setNeedsDisplay:YES];
//}


#pragma mark -
#pragma mark Public

- (void)addButtonForBookmark:(FUBookmark *)bmark {
    [self addButtonForBookmark:bmark atIndex:-1];
}


- (void)startedDraggingButton:(FUBookmarkBarButton *)button {
    NSParameterAssert([buttons containsObject:button]);

    [self setNeedsDisplay:YES];
    self.draggingButton = button;
    draggingExistingButton = YES;

    [[FUBookmarkController instance] removeBookmark:[draggingButton bookmark]];
    [buttons removeObject:draggingButton];
    [draggingButton setHidden:YES];
}


- (void)finishedDraggingButton {
    NSParameterAssert(draggingButton);
    self.draggingButton = nil;
    [self postBookmarksDidChangeNotification];
    [self layoutButtons];
    draggingExistingButton = NO;
}


#pragma mark -
#pragma mark NSDragging

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    [separator removeFromSuperview];
}


- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPoint p = [self convertPointFromBase:[sender draggingLocation]];
    [self updateSeparatorForPoint:p];
    return (NSDragOperationCopy|NSDragOperationMove);
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation op = NSDragOperationNone;
    
    BOOL canHandle = NO;
    
    if ([pboard hasURLs]) {
        canHandle = YES;
        op = NSDragOperationMove|NSDragOperationCopy;
    } 

    if (canHandle)  {
        NSPoint p = [self convertPointFromBase:[sender draggingLocation]];
        [self updateSeparatorForPoint:p];
        [self addSubview:separator];
    }
    return op;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)draggingInfo {
    [separator removeFromSuperview];

    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    BOOL result = NO;
    
    // TODO this line should not be necessary
    currDropIndex = (currDropIndex > [buttons count]) ? [buttons count] : currDropIndex;

    NSArray *bmarks = [FUBookmark bookmarksFromPasteboard:pboard];
    
    for (FUBookmark *bmark in bmarks) {
        [self addBookmark:bmark atIndex:currDropIndex];
        result = YES;
    }

    [self setNeedsDisplay:YES];
    return result;
}


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
    if (draggingButton) {
        [draggingButton removeFromSuperview];
    }
    [self setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark Private

- (NSButton *)newButtonWithBookmark:(FUBookmark *)bmark {
    NSButton *button = [[FUBookmarkBarButton alloc] initWithBookmarkBar:self bookmark:bmark];
    [button setTarget:self];
    [button setAction:@selector(performActionForButton:)];
    [button sizeToFit];
    
    NSSize buttonSize = [button frame].size;
    buttonSize.width += 8;
    if (buttonSize.width > BUTTON_MAX_WIDTH) {
        buttonSize.width = BUTTON_MAX_WIDTH;
    }
    [button setFrameSize:buttonSize];
    
    return button;
}


- (void)performActionForButton:(id)sender {
    [self setNeedsDisplay:YES];
    [overflowButton unhighlight];
    
    NSInteger index = 0;
    if ([sender isKindOfClass:[NSButton class]]) {
        index = [buttons indexOfObject:sender];
    } else {
        index = [overflowMenu indexOfItem:sender] + visibleButtonCount;
    }
    
    id item = [[[FUBookmarkController instance] bookmarks] objectAtIndex:index];
    
    [[[FUDocumentController instance] frontWindowController] bookmarkClicked:item];
}


- (void)updateSeparatorForPoint:(NSPoint)p {
    FUBookmarkBarButton *b = [self buttonAtX:p.x];
    CGFloat sepX = 0;
    if (b) {
        CGFloat start = NSMinX([b frame]);
        CGFloat end = start + NSWidth([b frame]);
        CGFloat mid = start + (end - start) / 2;
        if (p.x > mid) {
            sepX = end + BUTTON_SPACING / 2;
            currDropIndex++;
        } else {
            sepX = start - BUTTON_SPACING / 2;
        }
        sepX -= NSWidth([separator frame]) / 2;
        sepX = (sepX < SEPARATOR_MIN_X) ? SEPARATOR_MIN_X : sepX;
    }
    [separator setFrameOrigin:NSMakePoint(sepX, 0)];
    [self setNeedsDisplay:YES];
}


- (FUBookmarkBarButton *)buttonAtX:(CGFloat)x {
    currDropIndex = 0;
    if (!buttons.count) {
        return nil;
    }
    if (x < BUTTON_MARGIN_LEFT) {
        return [buttons objectAtIndex:0];
    }
    
    NSPoint p = NSMakePoint(x, NSHeight([self frame]) / 2);
    
    for (FUBookmarkBarButton *b in buttons) {
        if (NSPointInRect(p, [b frame])) {
            return b;
        } else if (p.x < NSMinX([b frame])) {
            return b;
        }
        currDropIndex++;
    }
    
    return [buttons lastObject];
}


- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
    [self layoutButtons];
}


- (void)addBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i {                  
    if (-1 == i) {
        [[FUBookmarkController instance] appendBookmark:bmark];
    } else {
        [[FUBookmarkController instance] insertBookmark:bmark atIndex:i];
    }
    [self addButtonForBookmark:bmark atIndex:i];
    
    [self postBookmarksDidChangeNotification];

    if (!draggingExistingButton) {
        [[[FUDocumentController instance] frontWindowController] runEditTitleSheetForBookmark:bmark];
    }
}


- (void)addButtonForBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i {
    NSButton *button = [self newButtonWithBookmark:bmark];
    
    if (-1 == i) {
        [buttons addObject:button];
    } else {
        [buttons insertObject:button atIndex:i];
    }

    [button release];
    [self layoutButtons];
}


- (void)layoutButtons {
    for (FUBookmarkBarButton *b in buttons) {
        [b removeFromSuperview];
    }
    [overflowButton removeFromSuperview];

    CGFloat barWidth = NSWidth([self frame]);
    CGFloat barHeight = NSHeight([self frame]);
    CGFloat buttonX = BUTTON_MARGIN_LEFT;
    CGFloat overflowButtonWidth = NSWidth([overflowButton frame]);
    CGFloat overflowButtonY = (barHeight - NSHeight([overflowButton frame])) / 2 - 1;
    BOOL overflowed = NO;
    visibleButtonCount = 0;
    for (FUBookmarkBarButton *b in buttons) {
        CGFloat buttonWidth = NSWidth([b frame]);
        CGFloat buttonHeight = NSHeight([b frame]);
        CGFloat buttonY = (barHeight - buttonHeight) / 2 - 1;
        
        if (buttonX + buttonWidth > barWidth - overflowButtonWidth) {
            if (!overflowed) {
                overflowed = YES;
                [self createOverflowMenu];
                [overflowButton setFrameOrigin:NSMakePoint(barWidth - overflowButtonWidth, overflowButtonY)];
                [self addSubview:overflowButton];
            }
            NSMenuItem *newMenuItem = [[[NSMenuItem alloc] initWithTitle:[b title] 
                                                                  action:@selector(performActionForButton:) 
                                                           keyEquivalent:@""] autorelease];
            [newMenuItem setTarget:self];
            [overflowMenu addItem:newMenuItem];
        } else {
            visibleButtonCount++;
            [self addSubview:b];
            [b setFrameOrigin:NSMakePoint(buttonX, buttonY)];
        }
        buttonX += buttonWidth;
        buttonX += BUTTON_SPACING;
    }    
}


- (void)createOverflowMenu {
    self.overflowMenu = [[[NSMenu alloc] init] autorelease];
    [overflowButton setMenu:overflowMenu];
    
    NSInteger buttonHeight = NSHeight([overflowButton frame]);
    NSInteger viewHeight = NSHeight([self frame]);
    NSInteger buttonWidth = NSWidth([overflowButton frame]);
    NSInteger viewWidth = NSWidth([self frame]);
    
    NSInteger buttonYCoordinate = (viewHeight-buttonHeight) / 2.;
    NSInteger buttonXCoordinate = viewWidth-buttonWidth;
    
    [overflowButton setFrameOrigin:NSMakePoint(buttonXCoordinate ,buttonYCoordinate)];
    [self addSubview:overflowButton];
}


- (void)bookmarksDidChange:(NSNotification *)n {
    [self removeAllButtons];
    for (FUBookmark *bmark in [[FUBookmarkController instance] bookmarks]) {
        [self addButtonForBookmark:bmark];
    }
}


- (void)removeAllButtons {
    for (FUBookmarkBarButton *b in buttons) {
        [b removeFromSuperview];
    }
    [overflowButton removeFromSuperview];
    self.buttons = [NSMutableArray array];
}


- (void)postBookmarksDidChangeNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:FUBookmarksDidChangeNotification object:nil];
}

@synthesize separator;
@synthesize buttons;
@synthesize overflowButton;
@synthesize overflowMenu;
@synthesize draggingButton;
@end
