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

#import "FUDownloadItem.h"

#define TAG_STRING_KEY @"tagString"
#define URL_KEY @"URL"
#define FILENAME_KEY @"filename"
#define PATH_KEY @"path"
#define ICON_KEY @"icon"
#define RECEIVED_LENGTH_KEY @"receivedLength"
#define EXPECTED_LENGTH_KEY @"expectedLength"
#define DONE_KEY @"done"

static NSUInteger sTagCount;

@interface FUDownloadItem ()
- (void)startObserving;
- (void)lengthDidChange;
- (void)determineRemainingTimeString;
@end

@implementation FUDownloadItem

+ (void)initialize {
    if ([FUDownloadItem class] == self) {
        [self resetTagCount];
    }
}


+ (void)resetTagCount {
    sTagCount = -1;
}


- (id)initWithURLDownload:(NSURLDownload *)aDownload {
    if (self = [super init]) {
        self.download = aDownload;
        self.tagString = [@(++sTagCount)stringValue];
        self.URL = [[aDownload request] URL];
        self.filename = [[URL absoluteString] lastPathComponent];
        self.expectedLength = 0;
        self.receivedLength = 0;
        self.icon = [[NSWorkspace sharedWorkspace] iconForFileType:[[URL absoluteString] pathExtension]];
        self.done = NO;
        self.busy = NO;
        self.canResume = YES;

        [self startObserving];
    }
    return self;
}


- (void)dealloc {
    [self removeObserver:self forKeyPath:RECEIVED_LENGTH_KEY];
    [self removeObserver:self forKeyPath:EXPECTED_LENGTH_KEY];
    [self removeObserver:self forKeyPath:DONE_KEY];
    
    self.startDate = nil;
    self.lastDisplayDate = nil;
    self.tagString = nil;
    self.URL = nil;
    self.download = nil;
    self.filename = nil;
    self.path = nil;
    self.icon = nil;
    self.status = nil;
    self.remainingTimeString = nil;
    [super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:RECEIVED_LENGTH_KEY] || [keyPath isEqualToString:EXPECTED_LENGTH_KEY] || [keyPath isEqualToString:DONE_KEY]) {
        [self lengthDidChange];
    }
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUDownloadItem %p \n\tfilename: %@, \n\tpath: %@, \n\tURL: %@, \n\treceivedLength: %lu, \n\texpectedLength: %lu>", self, filename, path, URL, (unsigned long)receivedLength, (unsigned long)expectedLength];
}


#pragma mark -
#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    [super init];
    self.tagString = [coder decodeObjectForKey:TAG_STRING_KEY]; ++sTagCount;
    self.URL = [coder decodeObjectForKey:URL_KEY];
    self.filename = [coder decodeObjectForKey:FILENAME_KEY];
    self.path = [coder decodeObjectForKey:PATH_KEY];
    self.icon = [coder decodeObjectForKey:ICON_KEY];
    self.expectedLength = [coder decodeIntegerForKey:EXPECTED_LENGTH_KEY];
    self.receivedLength = [coder decodeIntegerForKey:RECEIVED_LENGTH_KEY];
    self.done = [coder decodeBoolForKey:DONE_KEY];
    self.busy = NO;
    self.canResume = NO;
    
    [self startObserving];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:tagString forKey:TAG_STRING_KEY];
    [coder encodeObject:URL forKey:URL_KEY];
    [coder encodeObject:filename forKey:FILENAME_KEY];
    [coder encodeObject:path forKey:PATH_KEY];
    [coder encodeObject:icon forKey:ICON_KEY];
    [coder encodeInteger:expectedLength forKey:EXPECTED_LENGTH_KEY];
    [coder encodeInteger:receivedLength forKey:RECEIVED_LENGTH_KEY];
    [coder encodeBool:done forKey:DONE_KEY];
}


#pragma mark -
#pragma mark Private

- (void)startObserving {
    [self addObserver:self forKeyPath:RECEIVED_LENGTH_KEY options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:EXPECTED_LENGTH_KEY options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:DONE_KEY options:NSKeyValueObservingOptionNew context:NULL];
}


- (void)determineRemainingTimeString {

    // dont change in less that a second

    if (lastDisplayDate) {
        if (abs([lastDisplayDate timeIntervalSinceNow]) < 1.) {
            return;
        }
    }
    self.lastDisplayDate = [NSDate date];

    
    
    CGFloat secondsSinceStart = ceil(abs([startDate timeIntervalSinceNow]));

    if (secondsSinceStart < 10) { // seems very unreliable for first few seconds. so return nothing.
        self.remainingTimeString = @"";
        return;
    }
    
    CGFloat totalExpectedTime = secondsSinceStart / ratio;
    CGFloat remaingSeconds = totalExpectedTime - secondsSinceStart;
    
    if (remaingSeconds < 2) { // show nothing for less that 2 seconds
        self.remainingTimeString = @"";
    } else if (remaingSeconds < 60) { // seconds
        self.remainingTimeString = [NSString stringWithFormat:@" – %.0f seconds remaining", remaingSeconds];
    } else { // minutes
        NSInteger minutes = floor(remaingSeconds / 60);
        if (minutes <= 1) {
            self.remainingTimeString = @" – 1 minute remaining";
        } else {
            self.remainingTimeString = [NSString stringWithFormat:@" – %@ minutes remaining", [@(minutes)stringValue]];
        }
    }
}


- (void)lengthDidChange {
    if (receivedLength > expectedLength) {
        expectedLength = receivedLength;
    }
    
    if (expectedLength > 0) {
        self.ratio = (CGFloat)((CGFloat)receivedLength / (CGFloat)expectedLength);
    } else {
        self.ratio = 0;
    }
    
    NSString *units = nil;
    NSString *fmt = nil;
    CGFloat displayedReceivedLength = 0;
    CGFloat displayedExpectedLength = 0;
    CGFloat divisor = 0;
        
    if (expectedLength != -1 && expectedLength > (1024 * 1024)) {
        units = @"MB";
        fmt = done ? @"%.1f %@" : @"%.1f of %.1f %@%@";
        divisor = (CGFloat)(1024 * 1024);
    } else {
        units = @"KB";
        fmt = done ?  @"%.1f %@" : @"%.1f of %.1f %@%@";
        divisor = (CGFloat)1024;
    } 
    displayedReceivedLength = (CGFloat)((CGFloat)receivedLength / divisor);
    displayedExpectedLength = (CGFloat)((CGFloat)expectedLength / divisor);
    
    if (self.done) {
        self.status = [NSString stringWithFormat:fmt, displayedReceivedLength, units];
    } else {
        if (self.busy) {
            [self determineRemainingTimeString];
            self.status = [NSString stringWithFormat:fmt, displayedReceivedLength, displayedExpectedLength, units, remainingTimeString];
        } else {
            self.status = [NSString stringWithFormat:fmt, displayedReceivedLength, displayedExpectedLength, units, @""];
        }
    }
}

@synthesize startDate;
@synthesize lastDisplayDate;
@synthesize tagString;
@synthesize URL;
@synthesize download;
@synthesize filename;
@synthesize path;
@synthesize remainingTimeString;
@synthesize status;
@synthesize icon;
@synthesize expectedLength;
@synthesize receivedLength;
@synthesize ratio;
@synthesize isUserscript;
@synthesize busy;
@synthesize done;
@synthesize canResume;
@end
