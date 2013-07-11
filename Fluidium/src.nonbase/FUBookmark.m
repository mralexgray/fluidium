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

#import "FUBookmark.h"
#import "FUUtils.h"
#import "NSString+FUAdditions.h"
#import "NSPasteboard+FUAdditions.h"
#import "WebURLsWithTitles.h"

@interface FUBookmark ()
+ (NSString *)titleFromURLString:(NSString *)URLString;
@end

@implementation FUBookmark

+ (FUBookmark *)bookmarkWithTitle:(NSString *)t content:(NSString *)c {
    FUBookmark *bmark = [[[FUBookmark alloc] init] autorelease];
    if (t) {
        bmark.title = t;        
    }
    if (c) {
        bmark.content = c;
    }
    return bmark;
}


+ (NSArray *)bookmarksFromPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *bmarks = [NSMutableArray array];

    NSInteger i = 0;
    NSString *title = nil;

    if ([pboard hasWebURLs]) {
        NSArray *URLs = [WebURLsWithTitles URLsFromPasteboard:pboard];
        NSArray *titles = [WebURLsWithTitles titlesFromPasteboard:pboard];

        for (NSURL *URL in URLs) {
            NSString *URLString = [URL absoluteString];
            if ([URLString length]) {
                if (i < [titles count]) {
                    title = [titles objectAtIndex:i++];
                } else {
                    title = [self titleFromURLString:URLString];
                }
                
                FUBookmark *bmark = [FUBookmark bookmarkWithTitle:title content:URLString];
                [bmarks addObject:bmark];
            }
        }
    } else {
        NSArray *URLs = [pboard propertyListForType:NSURLPboardType];
        
        for (NSURL *URL in URLs) {
            NSString *URLString = [URL absoluteString];
            if ([URLString length]) {
                NSString *title = [self titleFromURLString:URLString];
                
                FUBookmark *bmark = [FUBookmark bookmarkWithTitle:title content:URLString];                
                [bmarks addObject:bmark];
            }
        }
    }
    
    return bmarks;
}


+ (NSString *)titleFromURLString:(NSString *)URLString {
    NSString *title = URLString;
    
    title = [title stringByTrimmingURLSchemePrefix];
    NSString *prefix = @"www.";
    title = [title hasPrefix:prefix] ? [title substringFromIndex:[prefix length]] : title;
    
    NSString *suffix = @"/";
    title = [title hasSuffix:suffix] ? [title substringWithRange:NSMakeRange(0, [title length] - [suffix length])] : title;

    return title;
}


- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Untitled", @"");
        self.content = @"";
    }
    return self;
}


- (void)dealloc {
    self.title = nil;
    self.content = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUBookmark %p %@>", self, title];
}


#pragma mark -
#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    [super init];
    self.title = [coder decodeObjectForKey:@"title"];
    self.content = [coder decodeObjectForKey:@"content"];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:title forKey:@"title"];
    [coder encodeObject:content forKey:@"content"];
}


- (void)writeAllToPasteboard:(NSPasteboard *)pboard {
    FUWriteAllToPasteboard(content, title, pboard);
}


- (void)writeWebURLsToPasteboard:(NSPasteboard *)pboard {
    FUWriteWebURLsToPasteboard(content, title, pboard);
}

@synthesize title;
@synthesize content;
@end
