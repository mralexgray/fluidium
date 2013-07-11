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

#import "CRTimelineViewController.h"
#import "CRTwitterUtils.h"
#import "CRTwitterPlugIn.h"
#import "CRThreadViewController.h"
#import "CRBarButtonItemView.h"
#import "CRTweet.h"
#import "CRMoreListItem.h"
#import "CRTweetListItem.h"
#import "CRTextView.h"
#import <Fluidium/FUPlugInAPI.h>

#define DEFAULT_FETCH_INTERVAL_MINS 3
#define ENABLE_INTERVAL_MINS .5

#define DEFAULT_FETCH_INTERVAL_SECS (DEFAULT_FETCH_INTERVAL_MINS * 60)
#define ENABLE_INTERVAL_SECS (ENABLE_INTERVAL_MINS * 60)

#define DEFAULT_STATUS_FETCH_COUNT 40

#define DATES_INTERVAL_SECS 30

#define TWEET_LIMIT 250

@interface CRTimelineViewController ()
- (id)initWithNibName:(NSString *)s bundle:(NSBundle *)b type:(CRTimelineType)t;

- (void)setUpNavBar;
- (void)showRefreshBarButtonItem;
- (void)showProgressBarButtonItem;
- (void)refreshTitle;
- (void)refreshWithSelectedUsername;
- (void)selectedUsernameChanged;

// fetching
- (void)beginFetchLoop;
- (BOOL)isTooSoonToFetchAgain;
- (void)killFetchTimer;
- (void)startFetchTimerWithDefaultDelay;
- (void)startFetchTimerWithDelay:(NSTimeInterval)delaySecs;
- (void)fetchTimerFired:(NSTimer *)t;
- (void)fetchLatestTimeline;
- (void)fetchEarlierTimeline;

- (void)killEnableTimer;
- (void)startEnableTimer;
- (void)enableTimerFired:(NSTimer *)t;
- (void)enableFetching;
- (void)showProgressBarButtonItem;

- (void)trimTweetList;
- (void)clearTweetList;
- (void)pushThread:(NSString *)statusID;
- (void)updateDisplayedDates;

- (void)killDatesTimer;
- (void)startDatesLoop;

- (unsigned long long)latestID;
- (unsigned long long)earliestID;

@property (nonatomic, retain) NSURL *defaultProfileImageURL;
@property (nonatomic, retain) NSMutableArray *newTweets;
@property (nonatomic, retain) NSMutableDictionary *tweetTable;
@property (nonatomic, retain) NSArray *tweetSortDescriptors;
@property (nonatomic, retain) NSTimer *fetchTimer;
@property (nonatomic, retain) NSTimer *enableTimer;
@property (nonatomic, retain) NSTimer *datesTimer;
@end

@implementation CRTimelineViewController

- (id)init {
    return [self initWithType:CRTimelineTypeHome];
}

    
- (id)initWithType:(CRTimelineType)t {
    return [self initWithNibName:@"CRTimelineView" bundle:[NSBundle bundleForClass:[CRTimelineViewController class]] type:t];
}


- (id)initWithNibName:(NSString *)s bundle:(NSBundle *)b {
    return [self initWithNibName:@"CRTimelineView" bundle:[NSBundle bundleForClass:[CRTimelineViewController class]] type:CRTimelineTypeHome];
}


- (id)initWithNibName:(NSString *)s bundle:(NSBundle *)b type:(CRTimelineType)t {
    if (self = [super initWithNibName:s bundle:b]) {
        type = t;
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(selectedUsernameDidChange:) name:CRTwitterSelectedUsernameDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(displayUsernamesDidChange:) name:CRTwitterDisplayUsernamesDidChangeNotification object:nil];
        
        NSSortDescriptor *desc = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
        self.tweetSortDescriptors = [NSArray arrayWithObject:desc];
        self.tweetTable = [NSMutableDictionary dictionary];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.displayedUsername = nil;
    self.defaultProfileImageURL = nil;
    self.newTweets = nil;
    self.tweetTable = nil;
    self.tweetSortDescriptors = nil;
    [self killFetchTimer];
    [self killEnableTimer];
    [self killDatesTimer];
    [super dealloc]; 
}


#pragma mark -
#pragma mark UMEViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpNavBar];
    [self refreshWithSelectedUsername];
}


- (void)viewDidUnload {
    [super viewDidUnload];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (CRTimelineTypeUser != type) {
        NSString *selectedUsername = [[CRTwitterPlugIn instance] selectedUsername];
        if (!displayedUsername) {
            self.displayedUsername = selectedUsername;
        } else {
            if (![displayedUsername isEqualToString:selectedUsername]) {
                [self selectedUsernameChanged];
            }
        }
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    visible = YES;

    [self beginFetchLoop];
    [self startDatesLoop];

    [listView setSelectedItemIndex:NSNotFound];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self killFetchTimer];
    [self killDatesTimer];
}


- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    visible = NO;
}


#pragma mark -
#pragma mark Notifications

- (void)selectedUsernameDidChange:(NSNotification *)n {
    [self selectedUsernameChanged];
}


- (void)displayUsernamesDidChange:(NSNotification *)n {
    [listView reloadData];
}


#pragma mark -
#pragma mark Actions

- (IBAction)accountSelected:(id)sender {
    NSString *newUsername = [sender representedObject];
    NSString *oldUsername = [[CRTwitterPlugIn instance] selectedUsername];
    
    if (![newUsername isEqualToString:oldUsername]) {
        [[CRTwitterPlugIn instance] setSelectedUsername:newUsername];
        [[NSNotificationCenter defaultCenter] postNotificationName:CRTwitterSelectedUsernameDidChangeNotification object:nil];
        [self beginFetchLoop];
    }
}


- (IBAction)fetchLatestStatuses:(id)sender {
    if (!visible || [self isTooSoonToFetchAgain]) {
        return;
    }
    
    [self trimTweetList];
    [self showProgressBarButtonItem];
    [self killFetchTimer];
    if (CRTimelineTypeUser != type) {
        [self startFetchTimerWithDefaultDelay];
    }
    [self fetchLatestTimeline];
}


- (IBAction)fetchEarlierStatuses:(id)sender {
    [self showProgressBarButtonItem];
    [self fetchEarlierTimeline];
}


- (IBAction)showAccountsPopUp:(id)sender {
    NSEvent *evt = [NSApp currentEvent];
    
    NSRect frame = [[self view] frame];
    NSPoint p = [[self view] convertPointToBase:frame.origin];
    p.y += NSHeight(frame) + 2;
    p.x += 5;
    
    NSEvent *click = [NSEvent mouseEventWithType:[evt type] 
                                        location:p
                                   modifierFlags:[evt modifierFlags] 
                                       timestamp:[evt timestamp] 
                                    windowNumber:[evt windowNumber] 
                                         context:[evt context]
                                     eventNumber:[evt eventNumber] 
                                      clickCount:[evt clickCount] 
                                        pressure:[evt pressure]]; 
    
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    
    NSMenuItem *item = nil;
    for (NSString *username in [[CRTwitterPlugIn instance] usernames]) {
        if ([username length]) {
            item = [[[NSMenuItem alloc] initWithTitle:username action:@selector(accountSelected:) keyEquivalent:@""] autorelease];
            [item setRepresentedObject:username];
            [item setTarget:self];
            [menu addItem:item];
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add Account...", @"") action:@selector(showPrefs:) keyEquivalent:@""] autorelease];
    [item setTarget:[CRTwitterPlugIn instance]];
    [menu addItem:item];
    
    [NSMenu popUpContextMenu:menu withEvent:click forView:[self view]];
}


- (IBAction)pop:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark -
#pragma mark Private

- (void)setUpNavBar {
    
    if (CRTimelineTypeUser == type) {
        
    } else {
        self.navigationItem.backBarButtonItem = [[[UMEBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Home", @"") 
                                                                                   style:UMEBarButtonItemStyleBack 
                                                                                  target:self 
                                                                                  action:@selector(pop:)] autorelease];

        self.navigationItem.leftBarButtonItem = [[[UMEBarButtonItem alloc] initWithBarButtonSystemItem:UMEBarButtonSystemItemUser
                                                                                                target:self
                                                                                                action:@selector(showAccountsPopUp:)] autorelease];

        [self showRefreshBarButtonItem];        
    }

}


- (void)showRefreshBarButtonItem {
    self.navigationItem.rightBarButtonItem = [[[UMEBarButtonItem alloc] initWithBarButtonSystemItem:UMEBarButtonSystemItemRefresh
                                                                                             target:self
                                                                                             action:@selector(fetchLatestStatuses:)] autorelease];
    self.navigationItem.rightBarButtonItem.enabled = fetchingEnabled;
}


- (void)showProgressBarButtonItem {
    self.navigationItem.rightBarButtonItem = [[[UMEActivityBarButtonItem alloc] init] autorelease];
    self.navigationItem.rightBarButtonItem.enabled = YES;
}


- (void)refreshTitle {
    switch (type) {
        case CRTimelineTypeHome:
            self.title = [[CRTwitterPlugIn instance] selectedUsername];
            break;
        case CRTimelineTypeMentions:
            self.title = NSLocalizedString(@"Mentions", @"");
            break;
        case CRTimelineTypeUser:
            self.title = displayedUsername;
            break;
        default:
            NSAssert(0, @"");
    }
}


- (void)refreshWithSelectedUsername {
    [self killFetchTimer];
    [self killEnableTimer];
    [self clearTweetList];

    self.tweets = nil;
    
    [self refreshTitle];
    
    fetchingEnabled = YES;
}
             
             
- (void)selectedUsernameChanged {
     self.displayedUsername = [[CRTwitterPlugIn instance] selectedUsername];
     [self setUpTwitterEngine];
     [self refreshWithSelectedUsername];
}


- (void)trimTweetList {
    NSUInteger count = [tweets count];
    if (count > TWEET_LIMIT) {
        NSRange r = NSMakeRange(TWEET_LIMIT, count - TWEET_LIMIT);
        [tweets removeObjectsInRange:r];
        [listView setSelectedItemIndex:NSNotFound];
        [listView reloadData];
    }
}


- (void)clearTweetList {
    if ([tweets count]) {
        self.tweets = [NSMutableArray array];
        [listView setSelectedItemIndex:NSNotFound];
        [listView reloadData];
    }
}


- (void)pushThread:(NSString *)statusID {
    CRThreadViewController *vc = [[[CRThreadViewController alloc] init] autorelease];
    vc.tweet = [tweetTable objectForKey:statusID];
    [self.navigationController pushViewController:vc animated:NO];
}


- (void)updateDisplayedDates {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(updateDisplayedDates) withObject:nil waitUntilDone:NO];
        return;
    }
    
    for (CRTweet *tweet in tweets) {
        [tweet updateAgo];
    }
    
    [listView reloadData];
}


#pragma mark -
#pragma mark Enabling Timer

- (void)killEnableTimer {
    if (enableTimer) {
        [enableTimer invalidate];
        self.enableTimer = nil;
    }
}


- (void)startEnableTimer {
    fetchingEnabled = NO;
    self.enableTimer = [NSTimer scheduledTimerWithTimeInterval:ENABLE_INTERVAL_SECS
                                                        target:self
                                                      selector:@selector(enableTimerFired:)
                                                      userInfo:nil
                                                       repeats:NO];
}

                        
- (void)enableTimerFired:(NSTimer *)t {
    [self enableFetching];
}


- (void)enableFetching {
    [self killEnableTimer];
    fetchingEnabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = fetchingEnabled;
}


#pragma mark -
#pragma mark Fetching

- (void)beginFetchLoop {
    NSTimeInterval fetchDelaySecs = 0;
    
    if ([self isTooSoonToFetchAgain]) {
        fetchDelaySecs = DEFAULT_FETCH_INTERVAL_SECS;
    }
    
    [self performSelector:@selector(fetchLatestStatuses:) withObject:self afterDelay:fetchDelaySecs];
    //    [self startFetchTimerWithDelay:fetchDelaySecs];
}


- (BOOL)isTooSoonToFetchAgain {
    return !fetchingEnabled;
}


- (void)killFetchTimer {
    if (fetchTimer) {
        [fetchTimer invalidate];
        self.fetchTimer = nil;
    }
}


- (void)startFetchTimerWithDefaultDelay {
    [self startFetchTimerWithDelay:DEFAULT_FETCH_INTERVAL_SECS];
}


- (void)startFetchTimerWithDelay:(NSTimeInterval)delaySecs {
    //NSLog(@"starting fetchTimer. delay %d", delaySecs);
    self.fetchTimer = [NSTimer scheduledTimerWithTimeInterval:delaySecs
                                                  target:self
                                                selector:@selector(fetchTimerFired:)
                                                userInfo:nil
                                                 repeats:NO];
}


- (void)fetchTimerFired:(NSTimer *)t {
    NSParameterAssert(t == fetchTimer);
    
    if ([t isValid]) {
        [self performSelectorOnMainThread:@selector(fetchLatestStatuses:) withObject:self waitUntilDone:NO];
        //        [self fetchLatestStatuses:self];
    }
}


#pragma mark -
#pragma mark Date Timer

- (void)killDatesTimer {
    if (datesTimer) {
        [datesTimer invalidate];
        self.datesTimer = nil;
    }
}


- (void)startDatesLoop {
    [self killDatesTimer];
    self.datesTimer = [NSTimer scheduledTimerWithTimeInterval:DATES_INTERVAL_SECS 
                                                       target:self 
                                                     selector:@selector(datesTimerFired:) 
                                                     userInfo:nil 
                                                      repeats:YES];
}


- (void)datesTimerFired:(NSTimer *)t {
    NSParameterAssert(t == datesTimer);
    
    if ([t isValid]) {
        [self updateDisplayedDates];
    }
}


#pragma mark -
#pragma mark MGTwitterEngineDelegate

- (unsigned long long)latestID {
    if ([tweets count]) {
        return [[[tweets objectAtIndex:0] identifier] unsignedLongLongValue];
    } else {
        return 0;
    }
}


- (unsigned long long)earliestID {
    if ([tweets count]) {
        return [[[tweets lastObject] identifier] unsignedLongLongValue] - 1;
    } else {
        return 0;
    }
}


- (void)fetchLatestTimeline {
    [self startEnableTimer];
    
    NSString *reqID = nil;
    if (CRTimelineTypeHome == type) {
        reqID = [twitterEngine getFollowedTimelineSinceID:[self latestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else if (CRTimelineTypeMentions == type) {
        reqID = [twitterEngine getRepliesSinceID:[self latestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else if (CRTimelineTypeUser == type) {
        reqID = [twitterEngine getUserTimelineFor:displayedUsername sinceID:[self latestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else {
        NSAssert(0, @"unknown timeline type");
    }
    
    reqID; // clang
    
    //    NSLog(@"%@: connectionIdentifier = %@", NSStringFromSelector(_cmd), reqID);
}


- (void)fetchEarlierTimeline {
    NSString *reqID = nil;
    if (CRTimelineTypeHome == type) {
        reqID = [twitterEngine getFollowedTimelineSinceID:0 withMaximumID:[self earliestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else if (CRTimelineTypeMentions == type) {
        reqID = [twitterEngine getRepliesSinceID:0 withMaximumID:[self earliestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else if (CRTimelineTypeUser == type) {
        reqID = [twitterEngine getUserTimelineFor:displayedUsername sinceID:0 withMaximumID:[self earliestID] startingAtPage:1 count:DEFAULT_STATUS_FETCH_COUNT];
    } else {
        NSAssert(0, @"unknown timeline type");
    }
    
    reqID; // clang
    
    //    NSLog(@"%@: connectionIdentifier = %@", NSStringFromSelector(_cmd), reqID);
}


- (void)requestSucceeded:(NSString *)connectionIdentifier {
    [super requestSucceeded:connectionIdentifier];
    //    NSLog(@"Request succeeded for connectionIdentifier = %@", connectionIdentifier);
}


- (void)requestFailed:(NSString *)connectionIdentifier withError:(NSError *)error {
    [super requestFailed:connectionIdentifier withError:error];
    
    [self showRefreshBarButtonItem];
    [self enableFetching];
}


- (void)statusesReceived:(NSArray *)inStatuses forRequest:(NSString *)requestID {
    self.newTweets = [super tweetsFromStatuses:inStatuses];
    //NSLog(@"received %d new Tweets", [newTweets count]);
    
    @synchronized(tweets) {
        if (tweets) {
            [tweets addObjectsFromArray:newTweets];
        } else {
            self.tweets = newTweets;
        }
        
        [tweets sortUsingDescriptors:tweetSortDescriptors];
    }
    
    if ([newTweets count]) {
        for (CRTweet *tweet in newTweets) {
            [tweetTable setObject:tweet forKey:[tweet.identifier stringValue]];
        }
        
        [newTweets sortUsingDescriptors:tweetSortDescriptors];
    }

    [listView setSelectedItemIndex:NSNotFound];
    [self updateDisplayedDates];
    [self showRefreshBarButtonItem];
}


- (void)directMessagesReceived:(NSArray *)messages forRequest:(NSString *)connectionIdentifier {
    //NSLog(@"Got direct messages for %@:\r%@", connectionIdentifier, messages);
}


- (void)connectionFinished:(NSString *)connectionIdentifier {
    //NSLog(@"Connection finished %@", connectionIdentifier);
}


#pragma mark -
#pragma mark MGTwitterEngine

- (void)setUpTwitterEngine {
    fetchingEnabled = YES;
    [super setUpTwitterEngine];
}


#pragma mark -
#pragma mark TDListViewDataSource

- (NSUInteger)numberOfItemsInListView:(TDListView *)lv {
    NSUInteger c = [tweets count];
    if (c) {
        return c + 1; // for moreButton
    } else {
        return 0;
    }
}


- (id)listView:(TDListView *)lv itemAtIndex:(NSUInteger)i {
    NSUInteger c = [tweets count];
    if (i == c) {
        CRMoreListItem *item = (CRMoreListItem *)[listView dequeueReusableItemWithIdentifier:[CRMoreListItem reuseIdentifier]];
        
        if (!item) {
            item = [[[CRMoreListItem alloc] init] autorelease];
            [item.moreButton setTarget:self];
            [item.moreButton setAction:@selector(fetchEarlierStatuses:)];
        }
        
        return item;
    } else {
        return [super listView:lv itemAtIndex:i];
    }
}


#pragma mark -
#pragma mark TDListViewDelegate

- (CGFloat)listView:(TDListView *)lv extentForItemAtIndex:(NSUInteger)i {
    NSUInteger c = [tweets count];
    if (i == c) {
        return [CRMoreListItem defaultHeight];
    } else {
        return [super listView:lv extentForItemAtIndex:i];
    }
}


- (void)listView:(TDListView *)lv itemWasDoubleClickedAtIndex:(NSUInteger)i {
    if (i >= 0 && i < [tweets count]) {
        CRTweet *tweet = [tweets objectAtIndex:i];
        [self pushThread:[tweet.identifier stringValue]];
    }
}

@synthesize displayedUsername;
@synthesize defaultProfileImageURL;
@synthesize newTweets;
@synthesize tweetTable;
@synthesize tweetSortDescriptors;
@synthesize fetchTimer;
@synthesize enableTimer;
@synthesize datesTimer;
@end
