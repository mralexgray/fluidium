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

#import <Foundation/Foundation.h>

@interface FUHandlerController : NSObject {
    NSMutableArray *handlers; // array of dicts: @"scheme"=>@"mailto", @"URLString"=>@"google.com?compose=%@". these are dicts cuz they use bindings and undo in the UI
    NSMutableDictionary *lookupTable;
}

+ (FUHandlerController *)instance;

- (void)save;
- (void)loadHandlers;

//  if there is no handler for the request returns NO. if there is, it handles it and 
- (NSURLRequest *)requestForRequest:(NSURLRequest *)req;

@property (nonatomic, retain) NSMutableArray *handlers;
@property (nonatomic, retain) NSMutableDictionary *lookupTable;
@end
