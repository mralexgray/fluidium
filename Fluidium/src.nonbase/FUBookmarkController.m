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

#import "FUBookmarkController.h"
#import "FUBookmark.h"
#import "FUBookmarkWindowController.h"
#import "FUApplication.h"
#import "FUDocumentController.h"
#import "FUUserDefaults.h"
#import "FUWindowController.h" // needed for bookmarkClicked: action
#import "FUUtils.h"
#import "FUNotifications.h"
#import "WebIconDatabase.h"
#import "WebIconDatabase+FUAdditions.h"

#define NUM_STATIC_ITEMS 3

@interface FUBookmarkController ()
- (void)setUpBookmarkMenu;
- (void)setUpBookmarks;
- (void)postBookmarksDidChangeNotification;
@end

@implementation FUBookmarkController

+ (FUBookmarkController *)instance {    
    static FUBookmarkController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUBookmarkController alloc] init];
        }
    }
    return instance;
}


- (id)init {
    if (self = [super init]) {
        [self setUpBookmarkMenu];
        [self setUpBookmarks];
    }
    return self;
}


- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.bookmarks = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Action

- (IBAction)openBookmarkInNewWindow:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [[FUDocumentController instance] loadURL:bmark.content destinationType:FUDestinationTypeWindow];
}


- (IBAction)openBookmarkInNewTab:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [[FUDocumentController instance] loadURL:bmark.content destinationType:FUDestinationTypeTab];
}


- (IBAction)copyBookmark:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [bmark writeAllToPasteboard:nil];
}


- (IBAction)deleteBookmark:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [self removeBookmark:bmark];
}


- (IBAction)editBookmarkTitle:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [[[FUDocumentController instance] frontWindowController] runEditTitleSheetForBookmark:bmark];
}


- (IBAction)editBookmarkContent:(id)sender {
    FUBookmark *bmark = [sender representedObject];
    [[FUBookmarkWindowController instance] beginEditingContentForBookmarkAtIndex:[bookmarks indexOfObject:bmark]];
}


#pragma mark -
#pragma mark Public

- (void)save {
    if (![NSKeyedArchiver archiveRootObject:bookmarks toFile:[[FUApplication instance] bookmarksFilePath]]) {
        NSLog(@"%@ could not write bookmarks to disk", [[FUApplication instance] appName]);
    }
}


- (void)appendBookmark:(FUBookmark *)bmark {
    [bookmarks addObject:bmark];
    [self performSelector:@selector(postBookmarksDidChangeNotification) withObject:nil afterDelay:0];
}


- (void)insertBookmark:(FUBookmark *)bmark atIndex:(NSInteger)i {
    [bookmarks insertObject:bmark atIndex:i];
    [self performSelector:@selector(postBookmarksDidChangeNotification) withObject:nil afterDelay:0];
}


- (void)removeBookmark:(FUBookmark *)bmark {
    [bookmarks removeObject:bmark];
    [self performSelector:@selector(postBookmarksDidChangeNotification) withObject:nil afterDelay:0];
}


- (NSMenu *)contextMenuForBookmark:(FUBookmark *)bmark {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    
    NSMenuItem *item = nil;
    if ([[FUUserDefaults instance] tabbedBrowsingEnabled]) {
        item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open in New Tab", @"")
                                           action:@selector(openBookmarkInNewTab:) 
                                    keyEquivalent:@""] autorelease];
        [item setTarget:self];
        [item setRepresentedObject:bmark];
        [item setOnStateImage:nil];
        [menu addItem:item];
    }
    
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open in New Window", @"")
                                       action:@selector(openBookmarkInNewWindow:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];
    
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open", @"")
                                       action:@selector(bookmarkClicked:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:nil];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];

    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Name", @"")
                                       action:@selector(editBookmarkTitle:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];
    
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Address", @"")
                                       action:@selector(editBookmarkContent:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];

    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", @"")
                                       action:@selector(copyBookmark:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];

    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", @"")
                                       action:@selector(deleteBookmark:) 
                                keyEquivalent:@""] autorelease];
    [item setTarget:self];
    [item setRepresentedObject:bmark];
    [item setOnStateImage:nil];
    [menu addItem:item];
    
    return menu;
}


#pragma mark -
#pragma mark Private

- (void)setUpBookmarkMenu {
    NSMenu *bookmarkMenu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Bookmarks", @"")] submenu];
    [bookmarkMenu setDelegate:self];
}


- (void)setUpBookmarks {
    NSString *path = [[FUApplication instance] bookmarksFilePath];
    
    BOOL exists, isDir;
    exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    
    if (exists) {
        @try {
            self.bookmarks = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        } @catch (NSException *e) {
            NSLog(@"%@ encountered error reading bookmarks on disk!\n%@", [[FUApplication instance] appName], [e reason]);
        }
    }
    
    if (!bookmarks) {
        self.bookmarks = [NSMutableArray array];
    }
}


- (void)postBookmarksDidChangeNotification {
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:FUBookmarksDidChangeNotification object:nil];
}


#pragma mark -
#pragma mark NSMenuDelegate

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu {
    return NUM_STATIC_ITEMS + [bookmarks count];
}


- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)i shouldCancel:(BOOL)shouldCancel {
    if (i < NUM_STATIC_ITEMS) {
        return YES;
    }
    
    i -= NUM_STATIC_ITEMS;
    
    FUBookmark *bmark = [bookmarks objectAtIndex:i];
    
    [item setAction:@selector(bookmarkClicked:)];
    [item setTitle:bmark.title];
    
    [item setImage:[[WebIconDatabase sharedIconDatabase] faviconForURL:bmark.content]];
    [item setRepresentedObject:bmark];
    
    return YES;
}

@synthesize bookmarks;
@end
