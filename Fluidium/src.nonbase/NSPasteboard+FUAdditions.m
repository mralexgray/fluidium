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

#import "NSPasteboard+FUAdditions.h"
#import "WebURLsWithTitles.h"

@implementation NSPasteboard (FUAdditions)

- (BOOL)hasURLs {
    return ([self hasWebURLs] || [[self types] containsObject:NSURLPboardType]);
}


- (BOOL)hasWebURLs {
    return [[self types] containsObject:WebURLsWithTitlesPboardType];
}


- (BOOL)hasTypeFromArray:(NSArray *)types {
    BOOL foundType = NO;

    for (id type in types) {
        if ([[self types] containsObject:type]) {
            foundType = YES;
            break;
        }
    }
    
    return foundType;
}

@end
