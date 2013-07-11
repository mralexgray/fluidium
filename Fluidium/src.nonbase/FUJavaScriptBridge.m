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

#import "FUJavaScriptBridge.h"
#import "FUJavaScriptMenuItem.h"
#import "FUJavaScriptGrowlNotification.h"
#import "FUIconController.h"
#import "FUApplication.h"
#import "FUUtils.h"
#import <Growl/Growl.h>

@interface FUJavaScriptBridge ()
- (NSString *)toString:(id)obj;
@end

@implementation FUJavaScriptBridge

- (id)init {
    if (self = [super init]) {

    }
    return self;
}


- (void)dealloc {
    self.dockBadge = nil;
    self.dockMenuItems = nil;
    self.onclick = nil;
    [super dealloc];
}


- (NSString *)description {
    return @"[object Fluid]";
}


#pragma mark -
#pragma mark Public

- (void)dockMenuItemClick:(FUJavaScriptMenuItem *)jsItem {
    [jsItem.function callWebScriptMethod:@"apply" withArguments:nil];
}


#pragma mark -
#pragma mark WebScripting

+ (NSString *)webScriptNameForKey:(const char *)name {
    if (0 == strcmp(name, "dockBadge")) {
        return @"dockBadge";
    } else if (0 == strcmp(name, "isGrowlRunning")) {
        return @"isGrowlRunning";
    } else {
        return nil;
    }
}


+ (NSString *)webScriptNameForSelector:(SEL)sel {
    if (@selector(showGrowlNotification:) == sel) {
        return @"showGrowlNotification";
    } else if (@selector(addDockMenuItemWithTitle:function:) == sel) {
        return @"addDockMenuItem";
    } else if (@selector(removeDockMenuItemWithTitle:) == sel) {
        return @"removeDockMenuItem";
    } else if (@selector(beep) == sel) {
        return @"beep";
    } else if (@selector(bounceDockIcon) == sel) {
        return @"bounceDockIcon";
    } else if (@selector(playSoundNamed:) == sel) {
        return @"playSound";
    } else {
        return nil;
    }
}


+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
    return (nil == [self webScriptNameForKey:name]);
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel {
    return (nil == [self webScriptNameForSelector:sel]);
}


#pragma mark -
#pragma mark JavaScript Properties

- (void)setDockBadge:(id)obj {
    NSString *s = [self toString:obj];
    if (s != dockBadge) {
        [dockBadge autorelease];
        dockBadge = [s copy];
    }
    [[FUIconController instance] setDockTileLabel:s];
}


- (BOOL)isGrowlRunning {
    return [GrowlApplicationBridge isGrowlRunning];
}


#pragma mark -
#pragma mark JavaScript Methods

- (void)showGrowlNotification:(id)arg {
    FUJavaScriptGrowlNotification *note = [FUJavaScriptGrowlNotification notificationFromWebScriptObject:arg];
    //NSLog(@"%@", notif);
    [GrowlApplicationBridge notifyWithTitle:note.title
                                description:note.desc 
                           notificationName:note.name
                                   iconData:note.iconData 
                                   priority:note.priority 
                                   isSticky:note.isSticky
                               clickContext:@""
                                 identifier:note.identifier];
}


- (void)addDockMenuItemWithTitle:(NSString *)title function:(WebScriptObject *)func {
    if (![title length] || !func) return;
    
    FUJavaScriptMenuItem *jsItem = [FUJavaScriptMenuItem menuItemWithTitle:title function:func];

    if (!dockMenuItems) {
        self.dockMenuItems = [NSMutableArray array];
    }
    
    [dockMenuItems addObject:jsItem];
}


- (void)removeDockMenuItemWithTitle:(NSString *)title {
    if (![title length]) return;
    
    NSInteger i = 0;
    for (FUJavaScriptMenuItem *jsItem in dockMenuItems) {
        if ([jsItem.title isEqualToString:title]) {
            break;
        }
        i++;
    }
    
    if (i < [dockMenuItems count]) {
        [dockMenuItems removeObjectAtIndex:i];
    }
}


- (void)beep {
    NSBeep();
}


- (void)bounceDockIcon {
    [NSApp requestUserAttention: NSInformationalRequest];
}


- (void)playSoundNamed:(id)obj {
    NSString *name = [self toString:obj];
    NSSound *sound = [NSSound soundNamed:name];
    if (sound) {
        [sound play];
    } else {
        NSLog(@"%@ couldn't find sound named: '%@'", [[FUApplication instance] appName], name);
    }
}


#pragma mark -
#pragma mark Private

- (NSString *)toString:(id)obj {
    if (FUIsWebUndefined(obj)) {
        return @"";
    } else if (FUIsWebScriptObject(obj)) {
        return [obj callWebScriptMethod:@"toString" withArguments:nil];
    } else {
        return [obj description];
    }
}

@synthesize dockBadge;
@synthesize dockMenuItems;
@synthesize onclick;
@end
