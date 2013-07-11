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

#import "FUNotifications.h"

// FUUINotifications
NSString *const FUHomeURLStringDidChangeNotification = @"FUHomeURLStringDidChangeNotification";
NSString *const FUApplicationVersionDidChangeNotification = @"FUApplicationVersionDidChangeNotification";

// FUUINotifications
NSString *const FUToolbarShownDidChangeNotification = @"FUToolbarShownDidChangeNotification";
NSString *const FUTabBarShownDidChangeNotification = @"FUTabBarShownDidChangeNotification";
NSString *const FUTabBarHiddenForSingleTabDidChangeNotification = @"FUTabBarHiddenForSingleTabDidChangeNotification";
NSString *const FUBookmarkBarShownDidChangeNotification = @"FUBookmarkBarShownDidChangeNotification";
NSString *const FUStatusBarShownDidChangeNotification = @"FUStatusBarShownDidChangeNotification";

// FUWindowControllerNotifications
NSString *const FUWindowControllerDidOpenNotification = @"FUWindowControllerDidOpenNotification";
NSString *const FUWindowControllerWillCloseNotification = @"FUWindowControllerWillCloseNotification";

NSString *const FUWindowControllerDidOpenTabNotification = @"FUWindowControllerDidOpenTabNotification";
NSString *const FUWindowControllerWillCloseTabNotification = @"FUWindowControllerWillCloseTabNotification";
NSString *const FUWindowControllerDidCloseTabNotification = @"FUWindowControllerDidCloseTabNotification";
NSString *const FUWindowControllerDidChangeSelectedTabNotification = @"FUWindowControllerDidChangeSelectedTabNotification";
NSString *const FUWindowControllerDidChangeTabOrderNotification = @"FUWindowControllerDidChangeTabOrderNotification";

NSString *const FUTabControllerKey = @"FUTabController";
NSString *const FUIndexKey = @"FUIndex";
NSString *const FUPriorIndexKey = @"FUPriorIndex";
NSString *const FUErrorKey = @"FUError";
NSString *const FUErrorDescriptionKey = @"FUErrorDescription";

// FUTabControllerNotifications
NSString *const FUTabControllerProgressDidStartNotification = @"FUTabControllerProgressDidStartNotification";
NSString *const FUTabControllerProgressDidChangeNotification = @"FUTabControllerProgressDidChangeNotification";
NSString *const FUTabControllerProgressDidFinishNotification = @"FUTabControllerProgressDidFinishNotification";

NSString *const FUTabControllerDidStartProvisionalLoadNotification = @"FUTabControllerDidStartProvisionalLoadNotification";
NSString *const FUTabControllerDidCommitLoadNotification = @"FUTabControllerDidCommitLoadNotification";
NSString *const FUTabControllerDidFinishLoadNotification = @"FUTabControllerDidFinishLoadNotification";
NSString *const FUTabControllerDidFailLoadNotification = @"FUTabControllerDidFailLoadNotification";
NSString *const FUTabControllerDidClearWindowObjectNotification = @"FUTabControllerDidClearWindowObjectNotification";
NSString *const FUTabControllerDidLoadDOMContentNotification = @"FUTabControllerDidLoadDOMContentNotification";


// FUWindowNotifications
NSString *const FUSpacesBehaviorDidChangeNotification = @"FUSpacesBehaviorDidChangeNotification";
NSString *const FUWindowLevelDidChangeNotification = @"FUWindowLevelDidChangeNotification";
NSString *const FUWindowOpacityDidChangeNotification = @"FUWindowOpacityDidChangeNotification";
NSString *const FUWindowsHaveShadowDidChangeNotification = @"FUWindowsHaveShadowDidChangeNotification";

// FUWebViewNotifications
NSString *const FUWebPreferencesDidChangeNotification = @"FUWebPreferencesDidChangeNotification";
NSString *const FUUserAgentStringDidChangeNotification = @"FUUserAgentStringDidChangeNotification";
NSString *const FUContinuousSpellCheckingDidChangeNotification = @"FUContinuousSpellCheckingDidChangeNotification";

// FUBookmarkNotifications
NSString *const FUBookmarksDidChangeNotification = @"FUBookmarksDidChangeNotification";

