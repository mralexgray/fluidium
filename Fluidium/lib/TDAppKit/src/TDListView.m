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

#import <TDAppKit/TDListView.h>
#import <TDAppKit/TDListItemView.h>
#import "TDListItemViewQueue.h"

#define DEFAULT_ITEM_EXTENT 44

@interface TDListView ()
- (void)layoutItems;
- (void)viewBoundsDidChange:(NSNotification *)n;

@property (nonatomic, retain) NSMutableArray *itemViews;
@property (nonatomic, retain) TDListItemViewQueue *itemViewQueue;
@end

@implementation TDListView

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [NSColor whiteColor];
        self.itemExtent = DEFAULT_ITEM_EXTENT;
        
        self.itemViewQueue = [[[TDListItemViewQueue alloc] init] autorelease];
        
        [self setPostsFrameChangedNotifications:YES];
        [self setPostsBoundsChangedNotifications:YES];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        //[nc addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:self];
        [nc addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewFrameDidChangeNotification object:self];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.scrollView = nil;
    self.backgroundColor = nil;
    self.itemViews = nil;
    self.itemViewQueue = nil;
    [super dealloc];
}


//- (void)viewFrameDidChange:(NSNotification *)n {
//
//}


- (void)viewBoundsDidChange:(NSNotification *)n {
    //    [self layoutItems];
}


#pragma mark -
#pragma mark Public

- (void)reloadData {
    //    [self layoutItems];
    [self setNeedsDisplay:YES];
}


- (id)dequeueReusableItemViewWithIdentifier:(NSString *)s {
    TDListItemView *itemView = [itemViewQueue dequeueWithIdentifier:s];
    [itemView prepareForReuse];
    return itemView;
}


- (NSInteger)indexForItemAtPoint:(NSPoint)p {
    NSInteger i = 0;
    for (id itemView in itemViews) {
        if (NSPointInRect(p, [itemView frame])) {
            return i;
        }
        i++;
    }
    return NSNotFound;
}


- (id)viewForItemAtIndex:(NSInteger)i {
    id listView = nil;
    
    NSInteger c = [itemViews count];
    if (c && i >= 0 && i < c) {
        listView = [itemViews objectAtIndex:i];
    }

    return listView;
}


#pragma mark -
#pragma mark NSView

- (BOOL)isFlipped {
    return YES;
}


- (BOOL)acceptsFirstResponder {
    return YES;
}


- (void)mouseDown:(NSEvent *)evt {
    [super mouseDown:evt];
    
    NSPoint p = [self convertPoint:[evt locationInWindow] fromView:nil];
    
    NSInteger i = [self indexForItemAtPoint:p];
    if (NSNotFound == i) {
        if ([evt clickCount] > 1) {
            if (delegate && [delegate respondsToSelector:@selector(listView:emptyAreaWasDoubleClicked:)]) {
                [delegate listView:self emptyAreaWasDoubleClicked:evt];
            }
        }
    } else {
        self.selectedItemIndex = i;
    }
}


- (void)viewWillDraw {
    [self layoutItems];
}


- (void)drawRect:(NSRect)dirtyRect {
    [backgroundColor set];
    NSRectFill(dirtyRect);
}


- (void)layoutItems {
    NSAssert(dataSource, @"TDListView must have a dataSource before doing layout");
    
    NSRect scrollViewBounds = [scrollView bounds];
    NSSize scrollContentSize = [scrollView contentSize];

    NSSize scrollSize = NSZeroSize;
    BOOL isPortrait = self.isPortrait;
    if (isPortrait) {
        scrollSize = NSMakeSize(scrollContentSize.width, scrollViewBounds.size.height);
    } else {
        scrollSize = NSMakeSize(scrollViewBounds.size.width, scrollContentSize.height);
    }
        
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat w = isPortrait ? scrollSize.width : 0;
    CGFloat h = isPortrait ? 0 : scrollSize.height;

    for (TDListItemView *itemView in itemViews) {
        [itemViewQueue enqueue:itemView withIdentifier:itemView.reuseIdentifier];
        [itemView removeFromSuperview];
    }
    
    NSInteger c = [dataSource numberOfItemsInListView:self];
    self.itemViews = [NSMutableArray arrayWithCapacity:c];

    NSInteger i = 0;
    for ( ; i < c; i++) {
        TDListItemView *listItem = [dataSource listView:self viewForItemAtIndex:i];
        NSAssert1(listItem, @"nil rowView returned for index: %d", i);
        
        // get row height
        NSInteger wh = itemExtent;
        if (delegate && [delegate respondsToSelector:@selector(listView:extentForItemAtIndex:)]) {
            wh = [delegate listView:self extentForItemAtIndex:i];
        }        
        
        if (isPortrait) {
            h = wh;
        } else {
            w = wh;
        }
        
        [listItem setFrame:NSMakeRect(x, y, w, h)];
        [self addSubview:listItem];

        [itemViews addObject:listItem];
        
        if (isPortrait) {
            y += wh; // add height for next row
            //if (y > scrollSize.height) break;
        } else {
            x += wh;
            //if (x > scrollSize.width) break;
        }
    }
    
    NSRect frame = [self frame];
    if (isPortrait) {
        y = y < scrollSize.height ? scrollSize.height : y;
        frame.size.height = y;
    } else {
        x = x < scrollSize.width ? scrollSize.width : x;
        frame.size.width = x;
    }
    [self setFrame:frame];
}


- (void)setSelectedItemIndex:(NSInteger)i {
    if (i != selectedItemIndex) {
        if (delegate && [delegate respondsToSelector:@selector(listView:willSelectItemAtIndex:)]) {
            if (-1 == [delegate listView:self willSelectItemAtIndex:i]) {
                return;
            }
        }
        
        selectedItemIndex = i;
        [self reloadData];
        
        if (delegate && [delegate respondsToSelector:@selector(listView:didSelectItemAtIndex:)]) {
            [delegate listView:self didSelectItemAtIndex:i];
        }
    }
}


- (BOOL)isPortrait {
    return TDListViewOrientationPortrait == orientation;
}


- (BOOL)landscape {
    return TDListViewOrientationLandscape == orientation;
}

@synthesize scrollView;
@synthesize dataSource;
@synthesize delegate;
@synthesize backgroundColor;
@synthesize itemExtent;
@synthesize selectedItemIndex;
@synthesize orientation;
@synthesize itemViews;
@synthesize itemViewQueue;
@end