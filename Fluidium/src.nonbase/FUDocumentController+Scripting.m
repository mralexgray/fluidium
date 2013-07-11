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

#import "FUDocumentController+Scripting.h"
#import "FUDocument+Scripting.h"
#import "FUWindowController.h"
#import "FUWindowController+Scripting.h"
#import "FUTabController.h"
#import <TDAppKit/NSAppleEventDescriptor+TDAdditions.h>
#import <TDAppKit/NSAppleEventDescriptor+NDAppleScriptObject.h>
#import <objc/runtime.h>

@implementation FUDocumentController (Scripting)

+ (void)initialize {
    if ([FUDocumentController class] == self) {
        
#if FU_SCRIPTING_ENABLED

        Method old = class_getInstanceMethod(self, @selector(newDocument:));
        Method new = class_getInstanceMethod(self, @selector(script_newDocument:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(newTab:));
        new = class_getInstanceMethod(self, @selector(script_newTab:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(newBackgroundTab:));
        new = class_getInstanceMethod(self, @selector(script_newBackgroundTab:));
        method_exchangeImplementations(old, new);

#endif
    }
}

    
#pragma mark -
#pragma mark Actions

- (IBAction)script_newDocument:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'crel'];
    NSAppleEventDescriptor *cls = [NSAppleEventDescriptor descriptorWithTypeCode:'fDoc'];
    [aevt setParamDescriptor:cls forKeyword:'kocl'];
    [aevt sendToOwnProcessNoReply]; 
}


// TODO do these two methods need to exist?
- (IBAction)script_newTab:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'crel'];
    NSAppleEventDescriptor *cls = [NSAppleEventDescriptor descriptorWithTypeCode:'fDoc'];
    [aevt setParamDescriptor:cls forKeyword:'kocl'];
    [aevt sendToOwnProcessNoReply]; 
}


- (IBAction)script_newBackgroundTab:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'crel'];
    NSAppleEventDescriptor *cls = [NSAppleEventDescriptor descriptorWithTypeCode:'fTab'];
    [aevt setParamDescriptor:cls forKeyword:'kocl'];
    
    NSDictionary *props = [NSDictionary dictionaryWithObject:[NSAppleEventDescriptor descriptorWithFalseBoolean] forKey:[NSNumber numberWithInteger:'tSel']];
    [aevt setParamDescriptor:[NSAppleEventDescriptor recordDescriptorWithDictionary:props] forKeyword:'prdt'];
    [aevt sendToOwnProcessNoReply]; 
}

@end
