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

#import "NSString+FUAdditions.h"
#import "FUUtils.h"

@implementation NSString (FUAdditions)

- (NSString *)stringByEnsuringURLSchemePrefix {
    if (![self hasSupportedSchemePrefix]) {
        return [NSString stringWithFormat:@"%@%@", kFUHTTPSchemePrefix, self];
    }
    return self;
}


- (NSString *)stringByTrimmingURLSchemePrefix {
    NSString *s = [[self copy] autorelease];
    
    if ([s hasPrefix:kFUHTTPSchemePrefix]) {
        s = [s substringFromIndex:[kFUHTTPSchemePrefix length]];
    } else if ([s hasPrefix:kFUHTTPSSchemePrefix]) {
        s = [s substringFromIndex:[kFUHTTPSSchemePrefix length]];
    } else if ([s hasPrefix:kFUFileSchemePrefix]) {
        s = [s substringFromIndex:[kFUFileSchemePrefix length]];
    } else if ([s hasPrefix:kFUJavaScriptSchemePrefix]) {
        s = [s substringFromIndex:[kFUJavaScriptSchemePrefix length]];
    }
 
    return s;
}


- (NSString *)stringByEnsuringTLDSuffix {
    if (![self hasTLDSuffix]) {
        return [NSString stringWithFormat:@"%@.com", self];
    }
    return self;
}


- (BOOL)hasHTTPSchemePrefix {
    return [self hasPrefix:kFUHTTPSchemePrefix] || [self hasPrefix:kFUHTTPSSchemePrefix];
}


- (BOOL)hasJavaScriptSchemePrefix {
    return [self hasPrefix:kFUJavaScriptSchemePrefix];
}


- (BOOL)hasSupportedSchemePrefix {
    return [self hasHTTPSchemePrefix] 
        || [self hasPrefix:kFUFileSchemePrefix] 
        || [self hasPrefix:@"mailto:"] 
        || [self hasPrefix:@"about:"] 
        || [self hasPrefix:@"data:"] 
        || [self hasPrefix:@"file:"] 
        || [self hasJavaScriptSchemePrefix];
}


- (BOOL)hasTLDSuffix {
    return (NSNotFound != [self rangeOfString:@"."].location);
}

@end
