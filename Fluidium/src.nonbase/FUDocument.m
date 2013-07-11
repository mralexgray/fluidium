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

#import "FUDocument.h"
#import "FUWindowController.h"
#import "FUTabController.h"
#import "FUWebView.h"
#import <WebKit/WebKit.h>

#define WEB_ARCHIVE_TYPENAME @"Web archive"
#define HTML_DOC_TYPENAME @"HTML document"

@interface FUDocument ()
- (void)webPrintOperationDidRun:(NSPrintOperation *)op success:(BOOL)success contextInfo:(id)dv;
@end

@implementation FUDocument

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.windowController = nil;
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUDocument %p %@>", self, [[windowController window] title]];
}


- (void)windowControllerDidShowVisiblePlugIns:(FUWindowController *)wc {
    
}


#pragma mark -
#pragma mark NSDocument

- (void)makeWindowControllers {
    self.windowController = [[[FUWindowController alloc] init] autorelease];
    [self addWindowController:windowController];
}


- (BOOL)isDocumentEdited {
    return NO;
}


//- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outErr {
//    if ([typeName isEqualToString:@"webarchive"]) {
//        NSData *data = [NSData dataWithContentsOfURL:absoluteURL];
//        WebArchive *archive = [[[WebArchive alloc] initWithData:data] autorelease];
//        [[[[[self windowController] selectedTabController] webView] mainFrame] loadArchive:archive];
//        return YES;
//    } else {
//        return [super readFromURL:absoluteURL ofType:typeName error:outErr];
//    }
//}
//
//
//- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outErr {
//    if ([typeName isEqualToString:@"webarchive"]) {
//        NSData *archiveData = [[[[[[windowController selectedTabController] webView] mainFrame] dataSource] webArchive] data];
//    
//        return [archiveData writeToURL:absoluteURL options:0 error:outErr];
//    } else {
//        return [super writeToURL:absoluteURL ofType:typeName error:outErr];
//    }
//}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outErr {
    if ([typeName isEqualToString:WEB_ARCHIVE_TYPENAME]) {
        WebArchive *archive = [[[WebArchive alloc] initWithData:data] autorelease];
        [[[[[self windowController] selectedTabController] webView] mainFrame] loadArchive:archive];
        return YES;
    } else if ([typeName isEqualToString:HTML_DOC_TYPENAME]) {
        [[[[[self windowController] selectedTabController] webView] mainFrame] loadData:data MIMEType:@"text/html" textEncodingName:nil baseURL:nil];
        return YES;
    } else {
        return [super readFromData:data ofType:typeName error:outErr];
    }
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outErr {
    if ([typeName isEqualToString:WEB_ARCHIVE_TYPENAME]) {
        NSData *archiveData = [[[[[[windowController selectedTabController] webView] mainFrame] dataSource] webArchive] data];
        return archiveData;
    } else if ([typeName isEqualToString:HTML_DOC_TYPENAME]) {
        NSData *HTMLData = [[[[[[[windowController selectedTabController] webView] mainFrame] dataSource] representation] documentSource] dataUsingEncoding:NSUTF8StringEncoding];
        return HTMLData;
    } else {
        return [super dataOfType:typeName error:outErr];
    }
}


#pragma mark -
#pragma mark Printing

- (void)printDocumentWithSettings:(NSDictionary *)settings showPrintPanel:(BOOL)show delegate:(id)delegate didPrintSelector:(SEL)sel contextInfo:(void *)ctx {
    WebView *wv = [[[self windowController] selectedTabController] webView];
    if (!wv) return;

    id dv = [[[wv mainFrame] frameView] documentView];
    [dv retain]; // retained
    
    NSPrintInfo *printInfo = [self printInfo];
    [printInfo setTopMargin:15];
    [printInfo setBottomMargin:15];
    [printInfo setLeftMargin:15];
    [printInfo setRightMargin:15];
    [printInfo setHorizontallyCentered:NO];
    [printInfo setVerticallyCentered:NO];
    
    // TODO prefs for print bg
    //  WebPreferences *preferences = [webView preferences];
    //    BOOL printBg = [preferences shouldPrintBackgrounds];
    
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:dv printInfo:printInfo];
    [op setShowsPrintPanel:show];
    [op runOperationModalForWindow:[wv window]
                          delegate:self 
                    didRunSelector:@selector(webPrintOperationDidRun:success:contextInfo:) 
                       contextInfo:dv];
}


- (void)webPrintOperationDidRun:(NSPrintOperation *)op success:(BOOL)success contextInfo:(id)dv {
    [dv release]; // released
}

@synthesize windowController;
@end
