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

#import <WebKit/WebKit.h>

@interface FUJavaScriptGrowlNotification : NSObject {
    NSString *identifier;
    NSString *title;
    NSString *desc;
    NSString *name;
    NSData *iconData;
    NSInteger priority;
    BOOL sticky;
    WebScriptObject *onclick;
}

+ (FUJavaScriptGrowlNotification *)notificationFromWebScriptObject:(WebScriptObject *)wso;

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, retain) NSData *iconData;
@property (nonatomic) NSInteger priority;
@property (nonatomic, getter=isSticky) BOOL sticky;
@property (nonatomic, retain) WebScriptObject *onclick;
@end
