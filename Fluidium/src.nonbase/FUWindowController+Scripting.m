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

#import "FUWindowController+Scripting.h"
#import "FUTabController.h"
#import "FUTabController+Scripting.h"
#import "FUShortcutController.h"
#import "FUShortcutCommand.h"
#import <TDAppKit/NSAppleEventDescriptor+TDAdditions.h>
#import <TDAppKit/NSAppleEventDescriptor+NDAppleScriptObject.h>
#import <objc/runtime.h>

@interface NSObject (FUScripting)
- (void)script_loadURL:(NSString *)s;
@end

@interface FUWindowController ()
@property (nonatomic, retain, readwrite) FUTabController *selectedTabController;
@end

@implementation FUWindowController (Scripting)

+ (void)initialize {
    if ([FUWindowController class] == self) {
        
#if FU_SCRIPTING_ENABLED

        Method old = class_getInstanceMethod(self, @selector(closeWindow:));
        Method new = class_getInstanceMethod(self, @selector(script_closeWindow:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(newTab:));
        new = class_getInstanceMethod(self, @selector(script_newTab:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(newBackgroundTab:));
        new = class_getInstanceMethod(self, @selector(script_newBackgroundTab:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(closeTab:));
        new = class_getInstanceMethod(self, @selector(script_closeTab:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(webGoBack:));
        new = class_getInstanceMethod(self, @selector(script_webGoBack:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(webGoForward:));
        new = class_getInstanceMethod(self, @selector(script_webGoForward:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(webReload:));
        new = class_getInstanceMethod(self, @selector(script_webReload:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(webStopLoading:));
        new = class_getInstanceMethod(self, @selector(script_webStopLoading:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(webGoHome:));
        new = class_getInstanceMethod(self, @selector(script_webGoHome:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(zoomIn:));
        new = class_getInstanceMethod(self, @selector(script_zoomIn:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(zoomOut:));
        new = class_getInstanceMethod(self, @selector(script_zoomOut:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(actualSize:));
        new = class_getInstanceMethod(self, @selector(script_actualSize:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(takeTabIndexToCloseFrom:));
        new = class_getInstanceMethod(self, @selector(script_takeTabIndexToCloseFrom:));
        method_exchangeImplementations(old, new);
        
        old = class_getInstanceMethod(self, @selector(selectTabController:));
        new = class_getInstanceMethod(self, @selector(script_selectTabController:));
        method_exchangeImplementations(old, new);

//        old = class_getInstanceMethod(self, @selector(setSelectedTabIndex:));
//        new = class_getInstanceMethod(self, @selector(script_setSelectedTabIndex:));
//        method_exchangeImplementations(old, new);
        
#endif
    }
}

#pragma mark -
#pragma mark NoScript Actions

- (IBAction)noscript_goToLocation:(id)sender {
    NSMutableString *ms = [[[locationComboBox stringValue] mutableCopy] autorelease];
    CFStringTrimWhitespace((CFMutableStringRef)ms);
    
    if (![ms length]) {
        return;
    }
    
    NSString *s = [[ms copy] autorelease];
    FUShortcutCommand *cmd = [shortcutController commandForInput:s];
    
    if (cmd) {
        s = cmd.firstURLString;
    }
    
    FUTabController *tc = [self selectedTabController];
    if ([tc respondsToSelector:@selector(script_loadURL:)]) {
        [tc script_loadURL:s]; // ! avoids scripting
    } else {
        [tc loadURL:s];
    }
    
    if (cmd.isTabbed) {
        for (NSString *URLString in cmd.moreURLStrings) {
            [self loadURL:[NSURLRequest requestWithURL:[NSURL URLWithString:URLString]] inNewTabAndSelect:NO];
        }
    }
}


#pragma mark -
#pragma mark Script Actions

- (IBAction)script_closeWindow:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'clos'];
    NSAppleEventDescriptor *docDesc = [[[self document] objectSpecifier] descriptor];
    [aevt setDescriptor:docDesc forKeyword:keyDirectObject];
    [aevt sendToOwnProcessNoReply];
}


- (IBAction)script_newTab:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'crel'];
    NSAppleEventDescriptor *cls = [NSAppleEventDescriptor descriptorWithTypeCode:'fTab'];
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


- (IBAction)script_closeTab:(id)sender {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'clos'];
    NSAppleEventDescriptor *tcDesc = [[[self selectedTabController] objectSpecifier] descriptor];
    [aevt setDescriptor:tcDesc forKeyword:keyDirectObject];
    [aevt sendToOwnProcessNoReply];
}


- (IBAction)script_webGoBack:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'Back'];
}


- (IBAction)script_webGoForward:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'Fwrd'];
}


- (IBAction)script_webReload:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'Reld'];
}


- (IBAction)script_webStopLoading:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'Stop'];
}


- (IBAction)script_webGoHome:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'Home'];
}


- (IBAction)script_zoomIn:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'ZoIn'];
}


- (IBAction)script_zoomOut:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'ZoOt'];
}


- (IBAction)script_actualSize:(id)sender {
    [NSAppleEventDescriptor sendVerbFirstEventWithFluidiumEventID:'ActS'];
}


- (IBAction)script_takeTabIndexToCloseFrom:(id)sender {
    FUTabController *tc = [self tabControllerAtIndex:[sender tag]];
    NSAssert([tc windowController] == self, @"");
    
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithClass:'core' eventID:'clos'];
    NSAppleEventDescriptor *tcDesc = [[tc objectSpecifier] descriptor];
    [aevt setDescriptor:tcDesc forKeyword:keyDirectObject];
    
    [aevt sendToOwnProcessNoReply];
}


- (void)script_selectTabController:(FUTabController *)tc {
    NSInteger i = [self indexOfTabController:tc];
    if (NSNotFound == i || i < 0) return;
    if (i > [tabView numberOfTabViewItems] - 1) return;
    
    // don't reselect the same tab. it effs up the priorSelectedTabIndex
    //if (tc == selectedTabController) return;
    
    NSInteger docIdx = [[NSApp orderedDocuments] indexOfObject:[self document]] + 1;
    NSInteger tabIdx = i + 1;
    
    OSErr err;
    AEBuildError buildErr;
            
    ProcessSerialNumber selfPSN = { 0, kCurrentProcess };
    AEDesc builtEvent, replyEvent;

    // 'core'\'setd'{ '----':'obj '{ 'form':'prop', 'want':'prop', 'seld':'dSTI', 'from':'obj '{ 'form':'indx', 'want':'fDoc', 'seld':1, 'from':'null'() } } }

    const char *eventFormat =
        "'----': 'obj '{ "         // Direct object is the file comment we want to modify
        "  form: enum(prop), "     //  ... the 'selected tab' is an object's property...
        "  seld: type(dSTb), "     //  ... specified by the 'dSTb' 4CC ...
        "  want: type(prop), "     //  ... which we want to interpret as a property (not as e.g. text).
        "  from: 'obj '{ "         // It's the property of an object...
        "      form: enum(indx), " //  ... that is an element ...
        "      want: type(fDoc), " //  ... of type 'fDoc' ...
        "      seld: @,"           //  ... selected by an index ...
        "      from: null() "      //  ... of the receiving application.
        "              }"
        "             }, "
        "data: 'obj '{ "           //  set the value of the specified direct object to an object ...
        "  form: enum(indx), "     //  ... that is an element ...
        "  seld: @, "              //  ... at index ...
        "  want: type(fTab), "     //  ... specified by the 'fTab' 4CC
        "  from: 'obj '{ "         // It's the element of an object...
        "      form: enum(indx), " //  ... that is an element ...
        "      want: type(fDoc), " //  ... of type 'fDoc' ...
        "      seld: @,"           //  ... selected by an index ...
        "      from: null() "      //  ... of the receiving application.
        "              }"
        "             } ";
    
    AEInitializeDesc(&builtEvent);
    AEInitializeDesc(&replyEvent);
    err = AEBuildAppleEvent(
            kAECoreSuite, kAESetData,
            typeProcessSerialNumber, &selfPSN, sizeof(selfPSN),
            kAutoGenerateReturnID, kAnyTransactionID,
            &builtEvent, 
            &buildErr, 
            eventFormat, 
            [[NSAppleEventDescriptor descriptorWithInt32:docIdx] aeDesc],
            [[NSAppleEventDescriptor descriptorWithInt32:tabIdx] aeDesc], 
            [[NSAppleEventDescriptor descriptorWithInt32:docIdx] aeDesc]);

    if (err != noErr) {
        [NSException raise:NSInternalInconsistencyException format:@"Unable to create AppleEvent: AEBuildAppleEvent() returns %d", err];
        NSLog(@"AEBuildErr : %d line %d", buildErr.fError, buildErr.fErrorPos);
    }
    
    err = AESendMessage(&builtEvent, &replyEvent, kAENoReply, kAEDefaultTimeout);
    
    AEDisposeDesc(&builtEvent);
    AEDisposeDesc(&replyEvent);
}

//- (void)script_setSelectedTabIndex:(NSInteger)i {
//    if (i < 0) return;
//    if (i > [tabView numberOfTabViewItems] - 1) return;
//    
//    // don't reselect the same tab. it effs up the priorSelectedTabIndex
//    NSInteger currentSelectedTabIndex = self.selectedTabIndex;
//    if (i == currentSelectedTabIndex) return;
//    
//    NSInteger docIdx = [[NSApp orderedDocuments] indexOfObject:[self document]] + 1;
//    NSInteger tabIdx = i + 1;
//    
//    OSErr err;
//    AEBuildError buildErr;
//            
//    ProcessSerialNumber selfPSN = { 0, kCurrentProcess };
//    AEDesc builtEvent, replyEvent;
//
//    // 'core'\'setd'{ '----':'obj '{ 'form':'prop', 'want':'prop', 'seld':'dSTI', 'from':'obj '{ 'form':'indx', 'want':'fDoc', 'seld':1, 'from':'null'() } } }
//
//    const char *eventFormat =
//        "'----': 'obj '{ "         // Direct object is the file comment we want to modify
//        "  form: enum(prop), "     //  ... the 'selected tab index' is an object's property...
//        "  seld: type(dSTI), "     //  ... selected by the 'dSTI' 4CC ...
//        "  want: type(prop), "     //  ... which we want to interpret as a property (not as e.g. text).
//        "  from: 'obj '{ "         // It's the property of an object...
//        "      form: enum(indx), "
//        "      want: type(fDoc), " //  ... of type 'fDoc' ...
//        "      seld: @,"           //  ... selected by an index ...
//        "      from: null() "      //  ... according to the receiving application.
//        "              }"
//        "             }, "
//        "data: @";                 // The data is what we want to set the direct object to.
//
//    AEInitializeDesc(&builtEvent);
//    AEInitializeDesc(&replyEvent);
//    err = AEBuildAppleEvent(
//            kAECoreSuite, kAESetData,
//            typeProcessSerialNumber, &selfPSN, sizeof(selfPSN),
//            kAutoGenerateReturnID, kAnyTransactionID,
//            &builtEvent, 
//            &buildErr, 
//            eventFormat, 
//            [[NSAppleEventDescriptor descriptorWithInt32:docIdx] aeDesc],
//            [[NSAppleEventDescriptor descriptorWithInt32:tabIdx] aeDesc]);
//
//    if (err != noErr) {
//        [NSException raise:NSInternalInconsistencyException format:@"Unable to create AppleEvent: AEBuildAppleEvent() returns %d", err];
//        NSLog(@"AEBuildErr : %d line %d", buildErr.fError, buildErr.fErrorPos);
//    }
//    
//    err = AESendMessage(&builtEvent, &replyEvent, kAENoReply, kAEDefaultTimeout);
//    
//    AEDisposeDesc(&builtEvent);
//    AEDisposeDesc(&replyEvent);
//}

@end
