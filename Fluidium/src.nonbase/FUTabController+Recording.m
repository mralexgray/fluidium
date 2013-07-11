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

#import "FUTabController+Recording.h"
#import "FUTabController+Scripting.h"
#import "FUWindowController.h"
#import "FUActivation.h"
#import "WebViewPrivate.h"
#import <TDAppKit/NSAppleEventDescriptor+TDAdditions.h>
#import <TDAppKit/NSAppleEventDescriptor+NDAppleScriptObject.h>
#import <TDAppKit/NSURLRequest+TDAdditions.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

#define RECORDING_ENABLED 0

typedef enum {
    WebNavigationTypePlugInRequest = WebNavigationTypeOther + 1
} WebExtraNavigationType;

@interface FUWindowController ()
- (void)handleCommandClick:(FUActivation *)act URL:(NSString *)s;
@end

#if RECORDING_ENABLED
@interface FUTabController (ScriptingPrivate)
- (void)script_loadURL:(NSString *)s;

- (BOOL)shouldHandleRequest:(NSURLRequest *)inReq;

- (void)script_submitForm:(NSURLRequest *)req withWebActionInfo:(NSDictionary *)info;
- (NSString *)XPathForFormInWebActionInfo:(NSDictionary *)info;
@end
#endif

@implementation FUTabController (Recording)
#if RECORDING_ENABLED

#pragma mark -
#pragma mark Web Recording

+ (void)initialize {
    if ([FUTabController class] == self) {
        
        Method old = class_getInstanceMethod(self, @selector(loadURL:));
        Method new = class_getInstanceMethod(self, @selector(script_loadURL:));
        method_exchangeImplementations(old, new);
        
    }
}


- (void)webView:(WebView *)wv decidePolicyForNavigationAction:(NSDictionary *)info request:(NSURLRequest *)req frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    if (![self shouldHandleRequest:req]) {
        [listener ignore];
        return;
    }
    
    WebNavigationType navType = [[info objectForKey:WebActionNavigationTypeKey] integerValue];
    
    if ([WebView _canHandleRequest:req]) {
        
        NSString *s = [[req URL] absoluteString];
        
        switch (navType) {
            case WebNavigationTypeOther:
            case WebNavigationTypeBackForward:
            case WebNavigationTypeReload:
                [listener use];
                break;
            case WebNavigationTypeLinkClicked:
            {
                FUActivation *act = [FUActivation activationFromWebActionInfo:info];
                if (act.isCommandKeyPressed) {
                    [listener ignore];
                    [windowController handleCommandClick:act URL:s];
                } else {
                    [listener ignore];
                    [self loadURL:s]; // send thru scripting
                }
            }
                break;
            case WebNavigationTypeFormSubmitted:
            case WebNavigationTypeFormResubmitted:
                if (submittingFromScript) {
                    submittingFromScript = NO;
                    [listener use];
                } else {
                    [listener use];
                    [self script_submitForm:req withWebActionInfo:info];
                }
                break;
            default:
                break;
        }
        
    } else if (WebNavigationTypePlugInRequest == navType) {
        [listener use];
    } else {
        // A file URL shouldn't fall through to here, but if it did, it would be a security risk to open it.
        if (![[req URL] isFileURL]) {
            [[NSWorkspace sharedWorkspace] openURL:[req URL]];
        }
        [listener ignore];
    }
}


- (void)script_loadURL:(NSString *)s {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithFluidiumEventID:'Load'];
    NSAppleEventDescriptor *tcDesc = [[self objectSpecifier] descriptor];
    [aevt setDescriptor:[NSAppleEventDescriptor descriptorWithString:s] forKeyword:keyDirectObject];
    [aevt setParamDescriptor:tcDesc forKeyword:'tPrm'];
    [aevt sendToOwnProcessNoReply];
}


- (void)script_submitForm:(NSURLRequest *)req withWebActionInfo:(NSDictionary *)info {
    NSAppleEventDescriptor *aevt = [NSAppleEventDescriptor appleEventWithFluidiumEventID:'Sbmt'];
    
    NSString *xpath = [self XPathForFormInWebActionInfo:info];
    if ([xpath length]) {
        [aevt setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:xpath] forKeyword:'XPth'];
    }
    
    NSDictionary *formValues = [req formValues];
    if ([formValues count]) {
        NSAppleEventDescriptor *formValuesDesc = [NSAppleEventDescriptor descriptorWithDictionary:formValues];
        [aevt setParamDescriptor:formValuesDesc forKeyword:'Vals'];
    }
    
    NSAppleEventDescriptor *tcDesc = [[self objectSpecifier] descriptor];
    [aevt setParamDescriptor:tcDesc forKeyword:'tPrm'];
    
    [aevt sendToOwnProcessNoReply];
}


- (NSString *)XPathForFormInWebActionInfo:(NSDictionary *)info {
    DOMHTMLFormElement *formEl = [info objectForKey:@"WebActionFormKey"];
    if (!formEl) {
        return nil;
    }

    DOMHTMLCollection *forms = [(DOMHTMLDocument *)[webView mainFrameDocument] forms];
    
    NSInteger formIndex = -1;
    
    NSInteger i = 0;
    NSInteger len = [forms length];
    for ( ; i < len; i++) {
        DOMNode *el = [forms item:i];
        if (el == formEl) {
            formIndex = i;
            break;
        }
    }
    
    NSAssert(formIndex > -1, @"");
    NSString *xpath = [NSString stringWithFormat:@"(//form)[%d]", formIndex];
    return xpath;
}

#endif
@end
