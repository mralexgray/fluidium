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

#import "FUJavaScriptGrowlNotification.h"

@interface WebScriptObject (FUAdditions)
- (BOOL)hasProperty:(NSString *)s;
- (id)propertyValueForKey:(NSString *)s;
@end

@implementation WebScriptObject (FUAdditions)

- (BOOL)hasProperty:(NSString *)s {
    return [[self callWebScriptMethod:@"hasOwnProperty" withArguments:[NSArray arrayWithObject:s]] boolValue];
}


- (id)propertyValueForKey:(NSString *)s {
    if ([self hasProperty:s]) {
        return [self valueForKey:s];
    } else {
        return nil;
    }
}

@end

@implementation FUJavaScriptGrowlNotification

+ (FUJavaScriptGrowlNotification *)notificationFromWebScriptObject:(WebScriptObject *)wso {
    FUJavaScriptGrowlNotification *note = [[[FUJavaScriptGrowlNotification alloc] init] autorelease];
    
    NSString *identifier = [wso propertyValueForKey:@"identifier"];
    if (identifier) {
        note.identifier = identifier;
    }

    NSString *title = [wso propertyValueForKey:@"title"];
    if (title) {
        note.title = title;
    }
    
    NSString *desc = [wso propertyValueForKey:@"description"];
    if (desc) {
        note.desc = desc;
    } 
    
    id icon = [wso propertyValueForKey:@"icon"];
    if (icon) {
        NSData *data = nil;
        if ([icon isKindOfClass:[DOMHTMLImageElement class]]) {
            DOMHTMLImageElement *el = (DOMHTMLImageElement *)icon;
            data = [[el image] TIFFRepresentation];
        } else if ([icon isKindOfClass:[NSString class]]) {
            NSImage *img = [[[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:icon]] autorelease];
            data = [img TIFFRepresentation];
        }
        note.iconData = data;
    } 
    
    NSNumber *priority = [wso propertyValueForKey:@"priority"];
    if (priority) {
        note.priority = [priority integerValue];
    }
    
    NSNumber *sticky = [wso propertyValueForKey:@"sticky"];
    if (sticky) {
        note.sticky = [sticky boolValue];
    }
    
    WebScriptObject *onclick = [wso propertyValueForKey:@"onclick"];
    if (onclick) {
        note.onclick = onclick;
    }
    
    return note;
}


- (id)init {
    if (self = [super init]) {
        self.title = @"";
        self.desc = @"";
        self.name = @"JavaScript Notification";
    }
    return self;
}


- (void)dealloc {
    self.identifier = nil;
    self.title = nil;
    self.desc = nil;
    self.name = nil;
    self.iconData = nil;
    self.onclick = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUJavaScriptGrowlNotification %p title: %@, desc: %@, pri: %d, sticky: %d>", self, title, desc, priority, sticky];
}

@synthesize identifier;
@synthesize title;
@synthesize desc;
@synthesize name;
@synthesize iconData;
@synthesize priority;
@synthesize sticky;
@synthesize onclick;
@end
