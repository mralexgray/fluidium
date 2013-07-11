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

#import "FUWindowController.h"

@interface FUWindowController (Scripting)
- (IBAction)noscript_goToLocation:(id)sender;

- (IBAction)script_closeWindow:(id)sender;
- (IBAction)script_newTab:(id)sender;
- (IBAction)script_newBackgroundTab:(id)sender;
- (IBAction)script_closeTab:(id)sender;
- (IBAction)script_webGoBack:(id)sender;
- (IBAction)script_webGoForward:(id)sender;
- (IBAction)script_webReload:(id)sender;
- (IBAction)script_webStopLoading:(id)sender;
- (IBAction)script_webGoHome:(id)sender;
- (IBAction)script_zoomIn:(id)sender;
- (IBAction)script_zoomOut:(id)sender;
- (IBAction)script_actualSize:(id)sender;
- (IBAction)script_takeTabIndexToCloseFrom:(id)sender;

- (void)script_selectTabController:(FUTabController *)tc;
//- (void)script_setSelectedTabIndex:(NSInteger)i;
@end
