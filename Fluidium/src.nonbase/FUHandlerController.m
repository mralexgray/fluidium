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

#import "FUHandlerController.h"
#import "FUUserDefaults.h"
#import "FUUtils.h"
#import "NSString+FUAdditions.h"

#define KEY_SCHEME @"scheme"
#define KEY_URLSTRING @"URLString"

@interface FUHandlerController ()
- (void)getEmailAddr:(NSString **)emailAddr args:(NSMutableDictionary **)args fromMailToURL:(NSString *)URLString;
@end

@implementation FUHandlerController

+ (FUHandlerController *)instance {
    static FUHandlerController *instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[FUHandlerController alloc] init];
        }
    }
    return instance;
}


- (id)init {
    if (self = [super init]) {
        [self loadHandlers];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.handlers = nil;
    self.lookupTable = nil;
    [super dealloc];
}


- (void)save {
    [[FUUserDefaults instance] setHandlers:handlers];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self loadHandlers]; // sets up the lookupTable again
}


- (void)loadHandlers {
    self.handlers = [NSMutableArray arrayWithArray:[[FUUserDefaults instance] handlers]];
    
    if ([handlers count]) {
        self.lookupTable = [NSMutableDictionary dictionaryWithCapacity:[handlers count]];
        for (NSDictionary *handler in handlers) {
            NSString *scheme = [handler objectForKey:KEY_SCHEME];
            if (scheme) {
                [lookupTable setObject:handler forKey:scheme];
            }
        }
    }
}


- (NSURLRequest *)requestForRequest:(NSURLRequest *)req {
    if (!lookupTable) return req;
    
    NSString *scheme = [[req URL] scheme];
    
    NSDictionary *handler = [lookupTable objectForKey:scheme];
    if (handler) {
        NSString *replacement = [handler objectForKey:KEY_URLSTRING];
        NSString *inURLString = [[[req URL] absoluteString] substringFromIndex:[scheme length] + 1];
        
        // custom logic for mailto (it's common)
        if ([scheme isEqualToString:@"mailto"]) {
            NSString *emailAddr = nil;
            NSMutableDictionary *args = [NSMutableDictionary dictionary];
            [self getEmailAddr:&emailAddr args:&args fromMailToURL:inURLString];
            if (emailAddr) {
                replacement = [replacement stringByAppendingString:emailAddr];
            }
            for (NSString *name in args) {
                NSString *value = [args objectForKey:name];
                [replacement stringByAppendingFormat:@"&%@=%@", name, value];
            }
        } else {
            replacement = [replacement stringByAppendingString:inURLString];
        }
        replacement = [replacement stringByEnsuringURLSchemePrefix];
        return [NSURLRequest requestWithURL:[NSURL URLWithString:replacement]];
    } else {
        return req;
    }
}


- (void)getEmailAddr:(NSString **)emailAddr args:(NSMutableDictionary **)args fromMailToURL:(NSString *)URLString {
	@try {
		NSMutableString *mstr = [[URLString mutableCopy] autorelease];
		[mstr replaceOccurrencesOfString:@"&amp;"
							  withString:@"&"
								 options:0
								   range:NSMakeRange(0, [mstr length])];
		
		NSString *argStr = @"";
		NSArray *splits = nil;
		
		if ([@"?" isEqualToString:[mstr substringWithRange:NSMakeRange(0, 1)]]) {
			argStr = [mstr substringWithRange:NSMakeRange(1, [mstr length] - 1)];
		} else if (NSNotFound == [mstr rangeOfString:@"?"].location) {
            if (emailAddr) *emailAddr = [NSString stringWithString:mstr];
		} else {
			splits = [mstr componentsSeparatedByString:@"?"];
			if (emailAddr) *emailAddr = [splits objectAtIndex:0];
			argStr = [splits objectAtIndex:1];
		}
		
		//NSLog(@"emailAddr: %@, argStr: %@", (*emailAddr), argStr);
		
		splits = [argStr componentsSeparatedByString:@"&"];
		
        if (args) {
            for (NSString *arg in splits) {
                NSArray *a = [arg componentsSeparatedByString:@"="];
                if (2 == [a count]) {
                    NSString *value = [[a objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    [(*args) setObject:value forKey:[a objectAtIndex:0]];
                }
            }
        }
		
		//NSLog(@"emailAddr: %@, args: %@", (*emailAddr), (*args));
        
	} @catch (NSException *e) {
		if (emailAddr) *emailAddr = @"";
		if (args) *args = nil;
	}
}

@synthesize handlers;
@synthesize lookupTable;
@end
