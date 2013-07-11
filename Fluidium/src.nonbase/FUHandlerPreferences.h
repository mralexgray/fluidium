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

#import "FUBasePreferences.h"

@interface FUHandlerPreferences : FUBasePreferences {
    NSArrayController *arrayController;
    NSMutableArray *handlers; // array of dicts: @"scheme"=>@"mailto", @"URLString"=>@"google.com?compose=%@". these are dicts cuz they use bindings and undo in the UI
}

- (void)insertObject:(NSMutableDictionary *)dict inHandlersAtIndex:(NSInteger)i;
- (void)removeObjectFromHandlersAtIndex:(NSInteger)i;

- (void)startObservingRule:(NSMutableDictionary *)rule;
- (void)stopObservingRule:(NSMutableDictionary *)rule;

- (void)loadHandlers;
- (void)storeHandlers;

@property (nonatomic, retain) IBOutlet NSArrayController *arrayController;
@property (nonatomic, retain) NSMutableArray *handlers;
@end
