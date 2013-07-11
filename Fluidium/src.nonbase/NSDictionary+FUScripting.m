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

#import "NSDictionary+FUScripting.h"

@implementation NSDictionary (FUScripting)

+ (id)scriptingRecordWithDescriptor:(NSAppleEventDescriptor *)inDesc {
    //NSLog(@"inDesc: %@", inDesc);
    
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    
    NSAppleEventDescriptor *withValuesParam = [inDesc descriptorForKeyword:'usrf']; // 'usrf' keyASUserRecordFields
    //NSLog(@"withValuesParam: %@", withValuesParam);
    
    NSString *name = nil;
    NSString *value = nil;
    
    // this is 1-indexed!
    NSInteger i = 1;
    NSInteger count = [withValuesParam numberOfItems];
    for ( ; i <= count; i++) {
        NSAppleEventDescriptor *desc = [withValuesParam descriptorAtIndex:i];
        //NSLog(@"descriptorAtIndex: %@", desc);
        
        NSString *s = [desc stringValue];
        if (name) {
            value = s;
            [d setObject:value forKey:name];
            name = nil;
            value = nil;
        } else {
            name = s;
        }
    }
    
    return [[d copy] autorelease];
}


//- (NSAppleEventDescriptor *)recordDescriptor {
//    NSAppleEventDescriptor *result = [NSAppleEventDescriptor recordDescriptor];
//    
//    NSAppleEventDescriptor *userFields = [NSAppleEventDescriptor listDescriptor];
//    [result setDescriptor:userFields forKeyword:keyASUserRecordFields];
//    
//    NSInteger i = 1; // this is 1-indexed!
//    for (NSString *key in self) {
//        NSString *value = [self objectForKey:key];
//        
//        [userFields insertDescriptor:<#(NSAppleEventDescriptor *)descriptor#> atIndex:<#(NSInteger)index#>
//    }
//        
//    NSString *name = nil;
//    NSString *value = nil;
//    
//    // this is 1-indexed!
//    NSInteger i = 1;
//    NSInteger count = [withValuesParam numberOfItems];
//    for ( ; i <= count; i++) {
//        NSAppleEventDescriptor *desc = [withValuesParam descriptorAtIndex:i];
//        //NSLog(@"descriptorAtIndex: %@", desc);
//        
//        NSString *s = [desc stringValue];
//        if (name) {
//            value = s;
//            [d setObject:value forKey:name];
//            name = nil;
//            value = nil;
//        } else {
//            name = s;
//        }
//    }
//}

@end
