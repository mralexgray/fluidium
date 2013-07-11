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

#import "FUJavaScriptMenuItem.h"

@implementation FUJavaScriptMenuItem

+ (FUJavaScriptMenuItem *)menuItemWithTitle:(NSString *)s function:(WebScriptObject *)func {
    FUJavaScriptMenuItem *item = [[[FUJavaScriptMenuItem alloc] init] autorelease];
    item.title = s;
    item.function = func;
    return item;
}


- (void)dealloc {
    self.title = nil;
    self.function = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUJavaScriptMenuItem %p %@>", self, title];
}

@synthesize title;
@synthesize function;
@end
