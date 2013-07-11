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

#import "FUActivation.h"
#import "FUUtils.h"
#import <TDAppKit/NSEvent+TDAdditions.h>
#import <TDAppKit/TDUtils.h>
#import <WebKit/WebKit.h>

@interface FUActivation ()
@property (nonatomic, readwrite, getter=isCommandClick) BOOL commandKeyPressed;
@property (nonatomic, readwrite, getter=isShiftClick) BOOL shiftKeyPressed;
@property (nonatomic, readwrite, getter=isOptionClick) BOOL optionKeyPressed;
@end

@implementation FUActivation

+ (id)activationFromEvent:(NSEvent *)evt {
    FUActivation *a = [[[self alloc] init] autorelease];
    
    a.commandKeyPressed = [evt isCommandKeyPressed] || [evt is3rdButtonClick];
    a.shiftKeyPressed   = [evt isShiftKeyPressed];
    a.optionKeyPressed  = [evt isOptionKeyPressed];
    
    return a;
}


+ (id)activationFromModifierFlags:(NSUInteger)flags {
    FUActivation *a = [[[self alloc] init] autorelease];
 
// TODO: by commenting above I am fixing the build... needs to be Fixed properly afterwords... 
//    a.commandKeyPressed = TDIsCommandKeyPressed(flags);
//    a.shiftKeyPressed   = TDIsShiftKeyPressed(flags);
//    a.optionKeyPressed  = TDIsOptionKeyPressed(flags);
    
    return a;
}

+ (id)activationFromWebActionInfo:(NSDictionary *)info {
    FUActivation *a = [[[self alloc] init] autorelease];
    
// TODO: by commenting above I am fixing the build... needs to be Fixed properly afterwords... 
//    NSUInteger flags = [[info objectForKey:WebActionModifierFlagsKey] unsignedIntegerValue];
//    BOOL isMiddleClick = (1 == [[info objectForKey:WebActionButtonKey] integerValue]);
    
//    a.commandKeyPressed = TDIsCommandKeyPressed(flags) || isMiddleClick;
//    a.shiftKeyPressed   = TDIsShiftKeyPressed(flags);
//    a.optionKeyPressed  = TDIsOptionKeyPressed(flags);

    return a;
}

@synthesize commandKeyPressed;
@synthesize shiftKeyPressed;
@synthesize optionKeyPressed;
@end
