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

#import "FUUtils.h"
#import "WebURLsWithTitles.h"

extern NSString *_NSPathForSystemFramework(NSString *framework);

NSString *const kFUHTTPSchemePrefix = @"http://";
NSString *const kFUHTTPSSchemePrefix = @"https://";
NSString *const kFUFileSchemePrefix = @"file://";
NSString *const kFUJavaScriptSchemePrefix = @"javascript:";

NSString *const kFUAboutBlank = @"about:blank";

//NSInteger kFUScriptErrorNumberTimeout = 1000;
NSInteger const kFUScriptErrorNumberInvalidArgument = 1001;
NSInteger const kFUScriptErrorNumberCantGoBack = 1002;
NSInteger const kFUScriptErrorNumberCantGoForward = 1003;
NSInteger const kFUScriptErrorNumberCantReload = 1004;
NSInteger const kFUScriptErrorNumberJavaScriptError = 1005;
NSInteger const kFUScriptErrorNumberXPathError = 1012;
NSInteger const kFUScriptErrorNumberUnixScriptError = 1006;
NSInteger const kFUScriptErrorNumberAppleScriptError = 1007;
NSInteger const kFUScriptErrorNumberAssertionFailed = 1008;
NSInteger const kFUScriptErrorNumberElementNotFound = 1009;
NSInteger const kFUScriptErrorNumberLoadFailed = 1010;
NSInteger const kFUScriptErrorNumberNotHTMLDocument = 1011;

NSColor *FUMainTabBackgroundColor() {
    static NSColor *color = nil;
    if (!color) {
        if (FUIsSnowLeopardOrLater()) {
            //color = [[NSColor colorWithDeviceRed:127.0/255.0 green:150.0/255.0 blue:177.0/255.0 alpha:1.0] retain];
            color = [[NSColor colorWithDeviceWhite:.65 alpha:1] retain];
        } else {
            color = [[NSColor colorWithDeviceWhite:.59 alpha:1] retain];
        }
    }
    return color;
}


NSColor *FUMainTabBorderColor() {
    static NSColor *color = nil;
    if (!color) {
        color = [[NSColor colorWithDeviceWhite:.45 alpha:1] retain];
    }
    return color;
}


NSColor *FUNonMainTabBorderColor() {
    static NSColor *color = nil;
    if (!color) {
        color = [[NSColor colorWithDeviceWhite:.69 alpha:1] retain];
    }
    return color;
}


NSDictionary *FUMainTabTextAttributes() {
    static NSDictionary *attrs = nil;
    if (!attrs) {
        NSColor *foregroundColor = [NSColor colorWithCalibratedWhite:.2 alpha:1];
        NSFont *font = [NSFont boldSystemFontOfSize:11];
        NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [paraStyle setAlignment:NSCenterTextAlignment];
        [paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
        if (FUIsSnowLeopardOrLater()) {
            [shadow setShadowColor:[NSColor colorWithCalibratedWhite:1 alpha:.51]];
        } else {
            [shadow setShadowColor:[NSColor colorWithCalibratedWhite:1 alpha:.38]];
        }
        [shadow setShadowOffset:NSMakeSize(0, -1)];
        [shadow setShadowBlurRadius:0];
        
        attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
                 foregroundColor, NSForegroundColorAttributeName,
                 font, NSFontAttributeName,
                 paraStyle, NSParagraphStyleAttributeName,
                 shadow, NSShadowAttributeName,
                 nil];
    }
    return attrs;
}


NSDictionary *FUNonMainTabTextAttributes() {
    static NSDictionary *attrs = nil;
    if (!attrs) {
        NSColor *foregroundColor = [NSColor colorWithCalibratedWhite:.4 alpha:1];
        NSFont *font = [NSFont boldSystemFontOfSize:11];
        NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [paraStyle setAlignment:NSCenterTextAlignment];
        [paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:1 alpha:.4]];
        [shadow setShadowOffset:NSMakeSize(0, 1)];
        [shadow setShadowBlurRadius:0];
        
        attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
                 foregroundColor, NSForegroundColorAttributeName,
                 font, NSFontAttributeName,
                 paraStyle, NSParagraphStyleAttributeName,
                 shadow, NSShadowAttributeName,
                 nil];
    }
    return attrs;
}



NSColor *FUNonMainTabBackgroundColor() {
    return [NSColor colorWithDeviceWhite:.84 alpha:1];
}


BOOL FUIsSnowLeopardOrLater() {
    NSUInteger major, minor, bugfix;
    FUGetSystemVersion(&major, &minor, &bugfix);
    return minor > 5;
}


void FUGetSystemVersion(NSUInteger *major, NSUInteger *minor, NSUInteger *bugfix) {
    OSErr err;
    SInt32 systemVersion, versionMajor, versionMinor, versionBugFix;
    if ((err = Gestalt(gestaltSystemVersion, &systemVersion)) != noErr) goto fail;
    if (systemVersion < 0x1040) {
        if (major) *major = ((systemVersion & 0xF000) >> 12) * 10 + ((systemVersion & 0x0F00) >> 8);
        if (minor) *minor = (systemVersion & 0x00F0) >> 4;
        if (bugfix) *bugfix = (systemVersion & 0x000F);
    } else {
        if ((err = Gestalt(gestaltSystemVersionMajor, &versionMajor)) != noErr) goto fail;
        if ((err = Gestalt(gestaltSystemVersionMinor, &versionMinor)) != noErr) goto fail;
        if ((err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix)) != noErr) goto fail;
        if (major) *major = versionMajor;
        if (minor) *minor = versionMinor;
        if (bugfix) *bugfix = versionBugFix;
    }
    
    return;
    
fail:
    NSLog(@"Unable to obtain system version: %ld", (long)err);
    if (major) *major = 10;
    if (minor) *minor = 0;
    if (bugfix) *bugfix = 0;
}


NSString *FUWebKitVersionString() {
    static NSString *sWebKitVersionString = nil;
    if (!sWebKitVersionString) {
        NSString *path = [_NSPathForSystemFramework(@"WebKit.framework") stringByAppendingPathComponent:@"Versions/A/Resources/version.plist"];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
        NSString *s = [d objectForKey:@"CFBundleVersion"];
        if ([s length] > 2) {
            // The value in the version.plist file looks like this. dunno what the leading '6' is for, but Safari removes it. so we will too. :|
            //        <key>CFBundleVersion</key>
            //        <string>6531.21.8</string>
            s = [s substringFromIndex:1];
        } else {
            // a reasonable default (Safari 4.0.4)
            s = @"531.21.10";
        }
        sWebKitVersionString = [[NSString alloc] initWithString:s];
    }
    return sWebKitVersionString;    
}


NSString *FUDefaultWebSearchFormatString() {
    return @"http://www.google.com/search?client=fluid&q=%@";
}


void FUWriteWebURLsToPasteboard(NSString *URLString, NSString *title, NSPasteboard *pboard) {
    pboard = pboard ? pboard : [NSPasteboard generalPasteboard];
    
    NSArray *types = [NSArray arrayWithObject:WebURLsWithTitlesPboardType];
    [pboard declareTypes:types owner:nil];
    
    [WebURLsWithTitles writeURLs:[NSArray arrayWithObject:[NSURL URLWithString:URLString]]
                       andTitles:[NSArray arrayWithObject:title]
                    toPasteboard:pboard];
}


void FUWriteAllToPasteboard(NSString *URLString, NSString *title, NSPasteboard *pboard) {
    pboard = pboard ? pboard : [NSPasteboard generalPasteboard];
    
    NSArray *types = [NSArray arrayWithObjects:WebURLsWithTitlesPboardType, NSURLPboardType, NSStringPboardType, nil];
    [pboard declareTypes:types owner:nil];
    
    NSURL *URL = [NSURL URLWithString:URLString];
    
    // write WebURLsWithTitlesPboardType type
    [WebURLsWithTitles writeURLs:[NSArray arrayWithObject:URL] andTitles:[NSArray arrayWithObject:title] toPasteboard:pboard];
    
    // write NSURLPboardType type
    [URL writeToPasteboard:pboard];
    
    // write NSStringPboardType type
    [pboard setString:URLString forType:NSStringPboardType];    
}

