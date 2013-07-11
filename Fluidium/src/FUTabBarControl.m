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

#import "FUTabBarControl.h"
#import "FUDocumentController.h"
#import "FUWindowController.h"
#import "FUTabController.h"

@interface PSMTabBarControl ()
- (id)cellForPoint:(NSPoint)point cellFrame:(NSRectPointer)outFrame;
- (void)closeTabClick:(id)sender;
@end

@interface FUWindowController ()
- (BOOL)removeTabViewItem:(NSTabViewItem *)tabItem;

- (void)tabControllerWasRemovedFromTabBar:(FUTabController *)tc;
- (void)tabControllerWasDroppedOnTabBar:(FUTabController *)tc;
@end

@interface FUTabBarControl ()
- (void)displayContextMenu:(NSTimer *)timer;
- (FUWindowController *)windowController;
@end

@implementation FUTabBarControl

- (void)dealloc {
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUTabBarControl %p (%d tabs) (%@)>", self, [[self representedTabViewItems] count], [[[self tabView] selectedTabViewItem] label]];
}


#pragma mark -
#pragma mark Overridden

- (void)closeTabClick:(id)sender {
    //NSTabViewItem *tabItem = [sender representedObject];
    //[[self windowController] removeTabViewItem:tabItem];
    
    // must go thru -takeTabIndexToCloseFrom: to get scripting recordability
    //NSLog(@"%@ index: %d", NSStringFromSelector(_cmd), [sender tag]);
    [[self windowController] takeTabIndexToCloseFrom:sender];
}


#pragma mark -
#pragma mark Events

- (void)rightMouseDown:(NSEvent *)evt {
    NSPoint mousePt = [self convertPoint:[evt locationInWindow] fromView:nil];
    NSRect cellFrame;
    PSMTabBarCell *cell = [super cellForPoint:mousePt cellFrame:&cellFrame];
    if (cell) {
        rightClickCellIndex = [_cells indexOfObject:cell];
        
        NSTimer *timer = [NSTimer timerWithTimeInterval:0 
                                                 target:self 
                                               selector:@selector(displayContextMenu:) 
                                               userInfo:evt 
                                                repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
}


#pragma mark -
#pragma mark Public

- (FUWindowController *)windowController {
    return [[self window] windowController];
}


#pragma mark -
#pragma mark Private

- (void)displayContextMenu:(NSTimer *)timer {
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
    
    NSMenu *menu = [[self windowController] contextMenuForTabAtIndex:rightClickCellIndex];
    [NSMenu popUpContextMenu:menu withEvent:click forView:self];
    [timer invalidate];
}

@end
