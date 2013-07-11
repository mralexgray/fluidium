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

#import "FUBookmarkWindowController.h"
#import "FUBookmark.h"
#import "FUBookmarkController.h"
#import "FUNotifications.h"

@interface FUBookmarkWindowController ()
- (void)postBookmarksDidChangeNotification;
- (void)update;

- (void)insertObject:(FUBookmark *)bmark inBookmarksAtIndex:(NSInteger)i;
- (void)removeObjectFromBookmarksAtIndex:(NSInteger)i;
- (void)startObservingBookmark:(FUBookmark *)bmark;
- (void)stopObservingBookmark:(FUBookmark *)bmark;
@end

@implementation FUBookmarkWindowController

+ (FUBookmarkWindowController *)instance {    
    static FUBookmarkWindowController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUBookmarkWindowController alloc] initWithWindowNibName:@"FUBookmarkWindow"];
        }
    }
    return instance;
}


- (id)initWithWindowNibName:(NSString *)name {    
    if (self = [super initWithWindowNibName:name]) {

    }
    return self;
}


- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.tableView = nil;
    self.arrayController = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(bookmarksDidChange:) name:FUBookmarksDidChangeNotification object:nil];
}


#pragma mark -
#pragma mark Actions

- (IBAction)insert:(id)sender {
    [arrayController insert:sender];
    [self performSelector:@selector(postBookmarksDidChangeNotification) withObject:nil afterDelay:0];
}


- (IBAction)remove:(id)sender {
    [arrayController remove:sender];
    [self performSelector:@selector(postBookmarksDidChangeNotification) withObject:nil afterDelay:0];
}


#pragma mark -
#pragma mark Public

- (void)appendBookmark:(FUBookmark *)bmark {
    [arrayController addObject:bmark];
}


- (void)insertBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i {
    [arrayController insertObject:bmark atArrangedObjectIndex:i];
}


- (void)removeBookmark:(FUBookmark *)bmark {
    [arrayController removeObject:bmark];
}


- (void)beginEditingContentForBookmarkAtIndex:(NSInteger)i {
    [[self window] makeKeyAndOrderFront:self];
    [arrayController setSelectionIndex:i];
    [tableView scrollRowToVisible:i];
}


- (NSMutableArray *)bookmarks {
    return [[FUBookmarkController instance] bookmarks];
}


#pragma mark -
#pragma mark Private

- (void)update {
    for (FUBookmark *bmark in self.bookmarks) {
        [self startObservingBookmark:bmark];
    }
    
    [arrayController setContent:self.bookmarks];
    
    [tableView reloadData];
    [tableView setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark ArrayController / Undo

- (void)insertObject:(FUBookmark *)bmark inBookmarksAtIndex:(NSInteger)i {
    NSUndoManager *undo = [[self window] undoManager];
    [[undo prepareWithInvocationTarget:self] removeObjectFromBookmarksAtIndex:i];

    [self startObservingBookmark:bmark];
    [self.bookmarks insertObject:bmark atIndex:i];
}


- (void)removeObjectFromBookmarksAtIndex:(NSInteger)i {
    FUBookmark *bmark = [self.bookmarks objectAtIndex:i];
    
    NSUndoManager *undo = [[self window] undoManager];
    [[undo prepareWithInvocationTarget:self] insertObject:bmark inBookmarksAtIndex:i];
    
    [self stopObservingBookmark:bmark];
    [self.bookmarks removeObjectAtIndex:i];
}


- (void)startObservingBookmark:(FUBookmark *)bmark {
    [bmark addObserver:self
            forKeyPath:@"title"
               options:NSKeyValueObservingOptionOld
               context:NULL];

    [bmark addObserver:self
            forKeyPath:@"content"
               options:NSKeyValueObservingOptionOld
               context:NULL];
}


- (void)stopObservingBookmark:(FUBookmark *)bmark {
    [bmark removeObserver:self forKeyPath:@"title"];
    [bmark removeObserver:self forKeyPath:@"content"];
}


- (void)changeKeyPath:(NSString *)keyPath ofObject:(id)obj toValue:(id)newValue {
    [obj setValue:newValue forKeyPath:keyPath];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj change:(NSDictionary *)change context:(void *)ctx {
    NSUndoManager *undo = [[self window] undoManager];
    id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
    [[undo prepareWithInvocationTarget:self] changeKeyPath:keyPath ofObject:obj toValue:oldValue];
}


#pragma mark -
#pragma mark Notifications

- (void)bookmarksDidChange:(NSNotification *)n {
    [self update];
}


- (void)postBookmarksDidChangeNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:FUBookmarksDidChangeNotification object:nil];
}


- (void)windowDidBecomeKey:(NSNotification *)n {
    [self update];
}


- (void)windowDidResignKey:(NSNotification *)n {
    [self postBookmarksDidChangeNotification];
}

@synthesize tableView;
@synthesize arrayController;
@end
