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

#import "NSNotificationCenter+FUDebug.h"
#import "FUTabController.h"
#import "FUWindowController.h"
#import "FUWindow.h"
#import "FUWebPreferences.h"
#import <objc/runtime.h>

// this category is only for debugging memory leaks. 
// should not be included in any targets or built into the final product
@implementation NSNotificationCenter (FUDebug)

- (void)new_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject {
    if (NO) {
        
//    } else if ([aName hasPrefix:@"FU"]) {
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", aName);


        // this works
//    } else if ([aName hasPrefix:@"WebPreferencesChangedNotification"] && [anObject isKindOfClass:[WebPreferences class]]) {
//        //        NSLog(@"isClass: %d", observer  == [WebView class]);
//        NSLog(@"observer: %@, sel: %s, name: %@ object: %@", observer, aSelector, aName, anObject);
//        //NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);

        
//    } else if ([NSStringFromClass([observer class]) isEqualToString:@"FUWebView"]) {
//        //        NSLog(@"isClass: %d", observer  == [WebView class]);
//        NSLog(@"observer: %@, sel: %s, name: %@ object: %@", observer, aSelector, aName, anObject);
//        //NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);

        
        
        
        
//    } else if ([aName hasPrefix:@"FUTab"]) {
//        //        NSLog(@"isClass: %d", observer  == [WebView class]);
//        NSLog(@"observer: %@, sel: %s, name: %@ object: %@", observer, aSelector, aName, anObject);
//        //NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
        
        
//    } else if ([aName hasPrefix:@"WebProgress"] /*&& observer == [WebView class]*/) {
//        NSLog(@"isClass: %d", observer  == [WebView class]);
//        NSLog(@"observer: %@, sel: %s, name: %@ object: %@", observer, aSelector, aName, anObject);
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
        
        
//    } else if ([anObject isKindOfClass:[FUTabController class]]) {
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
//    } else if ([anObject isKindOfClass:[WebView class]]) {
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
//    } else if ([anObject isKindOfClass:[FUWindowController class]]) {
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
//    } else if ([anObject isKindOfClass:[FUWindow class]]) {
//        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! %@", anObject);
    } else {
        [self new_addObserver:observer selector:aSelector name:aName object:anObject];
    }
    
//    if ([aName hasPrefix:@"FU"]) {
//        
//    } else {
//        [self new_addObserver:observer selector:aSelector name:aName object:anObject];
//    }
}

+ (void)initialize {
    if (self == [NSNotificationCenter class]) {
        
        Method old = class_getInstanceMethod(self, @selector(addObserver:selector:name:object:));
        Method new = class_getInstanceMethod(self, @selector(new_addObserver:selector:name:object:));
        method_exchangeImplementations(old, new);
        
    }
}

@end
