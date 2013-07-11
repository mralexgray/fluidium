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

#import "FUTabController.h"
#import "FUDocumentController.h"
#import "FUWindowController.h"
#import "FUWebPreferences.h"
#import "FUWhitelistController.h"
#import "FUHandlerController.h"
#import "FUUserDefaults.h"
#import "FUUtils.h"
#import "FUActivation.h"
#import "FUView.h"
#import "FUWebView.h"
#import "FURecentURLController.h"
#import "FUDownloadWindowController.h"
#import "FUNotifications.h"
#import "NSString+FUAdditions.h"
#import "DOMNode+FUAdditions.h"
#import "WebIconDatabase+FUAdditions.h"
#import "WebViewPrivate.h"
#import "WebUIDelegatePrivate.h"
#import "WebInspector.h"
#import "WebSecurityOriginPrivate.h"
#import "FUJavaScriptBridge.h"

#ifdef FAKE
#import "AutoTyper.h"
#endif    

//#import <Security/Security.h>
//#import <SecurityInterface/SFCertificateTrustPanel.h>

/*
 * Function: SSLSecPolicyCopy
 * Purpose:
 *   Returns a copy of the SSL policy.
 */
//static OSStatus SSLSecPolicyCopy(SecPolicyRef *ret_policy) {
//    SecPolicyRef policy;
//    SecPolicySearchRef policy_search;
//    OSStatus status;
//    
//    *ret_policy = NULL;
//    status = SecPolicySearchCreate(CSSM_CERT_X_509v3, &CSSMOID_APPLE_TP_SSL, NULL, &policy_search);
//    //status = SecPolicySearchCreate(CSSM_CERT_X_509v3, &CSSMOID_APPLE_X509_BASIC, NULL, &policy_search);
//    require_noerr(status, SecPolicySearchCreate);
//    
//    status = SecPolicySearchCopyNext(policy_search, &policy);
//    require_noerr(status, SecPolicySearchCopyNext);
//    
//    *ret_policy = policy;
//    
//SecPolicySearchCopyNext:
//    
//    CFRelease(policy_search);
//    
//SecPolicySearchCreate:
//    
//    return (status);
//}

typedef enum {
    WebNavigationTypePlugInRequest = WebNavigationTypeOther + 1
} WebExtraNavigationType;

@interface WebView (FUAdditions)
+ (BOOL)_canHandleRequest:(NSURLRequest *)req;
@end

@interface FUWindowController ()
- (void)handleCommandClick:(FUActivation *)act URL:(NSString *)s;
@end

@interface FUTabController ()
- (void)loadView;
- (BOOL)isViewLoaded;

- (void)setUpWebView;
- (void)handleLoadFail:(NSError *)err;
- (BOOL)willRetryWithTLDAdded:(WebView *)wv;
- (NSImage *)defaultFavicon;

- (void)postNotificationName:(NSString *)name;
- (void)postNotificationName:(NSString *)name userInfo:(NSDictionary *)additionalInfo;

- (BOOL)shouldHandleRequest:(NSURLRequest *)inReq;
- (BOOL)insertItem:(NSMenuItem *)item intoMenuItems:(NSMutableArray *)items afterItemWithTag:(NSInteger)tag;
- (NSInteger)indexOfItemWithTag:(NSUInteger)tag inMenuItems:(NSArray *)items;
- (NSString *)currentSelectionFromWebView;

- (void)openPanelDidEnd:(NSSavePanel *)openPanel returnCode:(NSInteger)code contextInfo:(id <WebOpenPanelResultListener>)listener;
- (void)savePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)code contextInfo:(NSURL *)URL;
//- (void)geolocationAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(id <WebGeolocationPolicyListener>)listener;

@property (nonatomic, assign, readwrite) FUWindowController *windowController; // weak ref
@property (nonatomic, retain) NSScriptCommand *suspendedCommand;
@end

@implementation FUTabController

- (id)init {
    return [self initWithWindowController:nil];
}


- (void)classDescriptionNeeded:(NSNotification *)n {
    
}


- (id)initWithWindowController:(FUWindowController *)wc {
    if (self = [super init]) {
        self.windowController = wc;
        self.javaScriptBridge = [[[FUJavaScriptBridge alloc] init] autorelease];

        // necessary to prevent bindings exceptions
        self.URLString = @"";
        self.title = NSLocalizedString(@"Untitled", @"");
        self.favicon = [self defaultFavicon];
        self.statusText = @"";
                
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(classDescriptionNeeded:) name:NSClassDescriptionNeededForClassNotification object:[self class]];
    }
    return self;
}


- (void)dealloc {
#ifdef FUDEBUG
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // taking some extra paranoid steps here with the webView to prevent crashing 
    // on one of the many callbacks/notifications that can be sent to or received by webviews
    // when the tab closes
    [[NSNotificationCenter defaultCenter] removeObserver:webView];
    [webView stopLoading:self];
    [webView setFrameLoadDelegate:nil];
    [webView setResourceLoadDelegate:nil];
    [webView setDownloadDelegate:nil];
    [webView setPolicyDelegate:nil];
    [webView setUIDelegate:nil];
    
    if (inspector) {
        [inspector webViewClosed];
    }
    
    self.view = nil;
    self.webView = nil;
    self.javaScriptBridge = nil;
    self.windowController = nil;
    self.URLString = nil;
    self.initialURLString = nil;
    self.title = nil;
    self.favicon = nil;
    self.statusText = nil;
    self.promptResultText = nil;
    self.promptView = nil;
    self.promptTextView = nil;
    self.inspector = nil;
    
    self.currentJavaScriptAlert = nil;
#ifdef FAKE
    self.autoTyper = nil;
    self.fileChooserPath = nil;
#endif    

    // be paranoid. resume the command JIC it has been suspended.
    if (suspendedCommand) {
        [suspendedCommand resumeExecutionWithResult:nil];
    }
    self.suspendedCommand = nil;
    
    [super dealloc];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<FUTabController %p %@>", self, title];
}


#pragma mark -
#pragma mark Actions

- (IBAction)webGoBack:(id)sender {
    [webView goBack:sender];
}


- (IBAction)webGoForward:(id)sender {
    [webView goForward:sender];
}


- (IBAction)webReload:(id)sender {
    if (self.lastLoadFailed) {
        [self loadURL:URLString];
    } else {
        [webView reload:sender];
    }
}


- (IBAction)webStopLoading:(id)sender {
    [webView stopLoading:sender];
}

- (void) webGoHome {
    [self loadURL:[[FUUserDefaults instance] homeURLString]];
    
}


- (IBAction)webGoHome:(id)sender {
    [self loadURL:[[FUUserDefaults instance] homeURLString]];
    
}


- (IBAction)zoomIn:(id)sender {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        [webView makeTextLarger:sender];
    } else {
        [webView zoomPageIn:sender];
    }
}


- (IBAction)zoomOut:(id)sender {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        [webView makeTextSmaller:sender];
    } else {
        [webView zoomPageOut:sender];
    }
}


- (IBAction)actualSize:(id)sender {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        [webView makeTextStandardSize:sender];
    } else {
        [webView resetPageZoom:sender];
    }
}


- (BOOL)canZoomIn {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        return [webView canMakeTextLarger];
    } else {
        return [webView canZoomPageIn];
    }
}


- (BOOL)canZoomOut {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        return [webView canMakeTextSmaller];
    } else {
        return [webView canZoomPageOut];
    }
}


- (BOOL)canActualSize {
    if ([[FUUserDefaults instance] zoomTextOnly]) {
        return [webView canMakeTextStandardSize];
    } else {
        return [webView canResetPageZoom];
    }
}


- (IBAction)openLinkInNewTabFromMenu:(id)sender {
    NSDictionary *clickElementInfo = [sender representedObject];
    NSString *s = [[clickElementInfo objectForKey:WebElementLinkURLKey] absoluteString];
    [[FUDocumentController instance] loadURL:s destinationType:FUDestinationTypeTab];
}


- (IBAction)openLinkInNewWindowFromMenu:(id)sender {
    NSDictionary *clickElementInfo = [sender representedObject];
    NSString *s = [[clickElementInfo objectForKey:WebElementLinkURLKey] absoluteString];
    [[FUDocumentController instance] loadURL:s destinationType:FUDestinationTypeWindow];
}


- (IBAction)openFrameInNewWindowFromMenu:(id)sender {
    NSDictionary *clickElementInfo = [sender representedObject];
    WebFrame *frame = [clickElementInfo objectForKey:WebElementFrameKey];
    NSString *s = [[[[frame dataSource] mainResource] URL] absoluteString];
    [[FUDocumentController instance] loadURL:s destinationType:FUDestinationTypeWindow];
}


- (IBAction)openImageInNewWindowFromMenu:(id)sender {
    NSDictionary *clickElementInfo = [sender representedObject];
    NSString *s = [[clickElementInfo objectForKey:WebElementLinkURLKey] absoluteString];
    [[FUDocumentController instance] loadURL:s destinationType:FUDestinationTypeWindow];
}


- (IBAction)searchWebFromMenu:(id)sender {
    NSString *term = [self currentSelectionFromWebView];
    if (![term length]) {
        NSBeep();
        return;
    }
    
    NSString *s = [NSString stringWithFormat:FUDefaultWebSearchFormatString(), term];
    [[FUDocumentController instance] loadURL:s];
}


- (IBAction)downloadLinkAsFromMenu:(id)sender {
    NSDictionary *clickElementInfo = [sender representedObject];
    NSURL *URL = [clickElementInfo objectForKey:WebElementLinkURLKey];
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories:YES];
    [savePanel setMessage:NSLocalizedString(@"Download Linked File As…", @"")];
    NSString *filename = [[URL absoluteString] lastPathComponent];
    
    [savePanel beginSheetForDirectory:nil 
                                 file:filename 
                       modalForWindow:[self.view window] 
                        modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
                          contextInfo:[URL retain]]; // retained
}


- (IBAction)showWebInspector:(id)sender {
    if (!inspector) {
        self.inspector = [[[WebInspector alloc] initWithWebView:webView] autorelease];
    }
    [inspector show:sender];
}


- (IBAction)showErrorConsole:(id)sender {
    if (!inspector) {
        self.inspector = [[[WebInspector alloc] initWithWebView:webView] autorelease];
    }
    [inspector showConsole:sender];
}


#pragma mark -
#pragma mark Public

- (NSView *)view {
    if (![self isViewLoaded]) {
        [self loadView];
    }
    return view;
}


- (void)loadView {
    if ([self isViewLoaded]) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, MAXFLOAT, MAXFLOAT);
    
    self.view = [[[FUView alloc] initWithFrame:frame] autorelease];
    [view setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    
    self.webView = [[[FUWebView alloc] initWithFrame:frame] autorelease];
    
    [self setUpWebView];
    
    [view addSubview:webView];
    
#ifdef FAKE
    self.autoTyper = [AutoTyper autoTyperWithWebView:webView];
#endif        
}


- (BOOL)isViewLoaded {
    return nil != view;
}


- (CGFloat)estimatedProgress {
    CGFloat progress = [webView estimatedProgress];

    if ([webView isLoading] && progress < .10) {
        progress = .10;
    }
    
    return progress;
}


- (NSString *)documentSource {
    return [[[[webView mainFrame] dataSource] representation] documentSource];
}


- (void)loadURL:(NSString *)s {
    if (![s length]) {
        return;
    }
        
    self.title = NSLocalizedString(@"Loading...", @"");
    self.URLString = [s stringByEnsuringURLSchemePrefix];
    [webView setMainFrameURL:URLString];
}


#pragma mark -
#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)wv didStartProvisionalLoadForFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;
    
    self.URLString = [[[[frame provisionalDataSource] request] URL] absoluteString];
    self.title = NSLocalizedString(@"Loading…", @"");

    [self postNotificationName:FUTabControllerDidStartProvisionalLoadNotification];
}


- (void)trustPanelDidEnd:(NSWindow *)sheet returnCode:(int)code contextInfo:(void *)ctx {
    
}


- (void)webView:(WebView *)wv didFailProvisionalLoadWithError:(NSError *)err forFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;
    
//    Error Domain=NSURLErrorDomain 
//    Code=-1202 
//    UserInfo=0x115267790 "The certificate for this server is invalid. You might be connecting to a server that is pretending to be “fa.keyes.ie” which could put your confidential information at risk." Underlying Error=(Error Domain=kCFErrorDomainCFNetwork Code=-1202 UserInfo=0x115264c40 "The certificate for this server is invalid. You might be connecting to a server that is pretending to be “fa.keyes.ie” which could put your confidential information at risk."
//    
//    // NSURLErrorServerCertificateUntrusted = -1202
//    if ([err code] == NSURLErrorServerCertificateUntrusted) {
//        
//        NSWindow *win = [webView window];
//        SEL sel = @selector(trustPanelDidEnd:returnCode:contextInfo:);
//        NSString *msg = @"msg";
//        
//        OSStatus status;
//        
//        SecCertificateRef cert = NULL;
//        
//        status = SecCertificateCreateFromData(const CSSM_DATA *data, CSSM_CERT_TYPE type, CSSM_CERT_ENCODING encoding, SecCertificateRef *certificate);
//        
//        // SecIdentityRef identity = NULL;
//        // status = SecIdentityCopyCertificate(identity, &cert);
//        
//        SecPolicyRef sslPolicy = NULL;
//        status = SSLSecPolicyCopy(&sslPolicy);
//        
//        NSArray *certs = [NSArray arrayWithObject:(id)cert];
//        
//        SecTrustRef trust = NULL;
//        status = SecTrustCreateWithCertificates((CFArrayRef)certs, sslPolicy, &trust);
//        
//        [[SFCertificateTrustPanel sharedCertificateTrustPanel] beginSheetForWindow:win modalDelegate:self didEndSelector:sel contextInfo:NULL trust:trust message:msg];
//        
//        [[SFCertificateTrustPanel sharedCertificateTrustPanel] beginSheetForWindow:win modalDelegate:self didEndSelector:sel contextInfo:NULL trust:trust message:msg];
//        
//        
//    } else {
        if (![self willRetryWithTLDAdded:wv]) {
            [self handleLoadFail:err];
        }
//    }
}


- (void)webView:(WebView *)wv didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;
    
    if (![initialURLString length]) {
        NSString *s = [[[[frame provisionalDataSource] request] URL] absoluteString];
        self.initialURLString = s;
    }
}


- (void)webView:(WebView *)wv didCommitLoadForFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;
    
    didReceiveTitle = NO;
    
    NSString *s = [webView mainFrameURL];
    self.URLString = s;
    self.favicon = [self defaultFavicon];
    
    [[self.view window] makeFirstResponder:webView];
    
    // remove old dock menu items
    javaScriptBridge.dockMenuItems = nil;

    [self setValue:[NSNumber numberWithBool:YES] forKey:@"canReload"];
    [self postNotificationName:FUTabControllerDidCommitLoadNotification];
}


- (void)webView:(WebView *)wv didReceiveTitle:(NSString *)s forFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;

    didReceiveTitle = YES;
    self.title = s;
}


- (void)webView:(WebView *)wv didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame {
    if (frame != [webView mainFrame]) return;
    
    self.favicon = image;
}


- (void)webView:(WebView *)wv didFinishLoadForFrame:(WebFrame *)frame {
    if (frame == [webView mainFrame]) {
        if (!didReceiveTitle) {
            self.title = URLString;
        }
    }

    [self postNotificationName:FUTabControllerDidFinishLoadNotification];
}


- (void)webView:(WebView *)wv didFailLoadWithError:(NSError *)err forFrame:(WebFrame *)frame {
    //if (frame != [webView mainFrame]) return;

    [self handleLoadFail:err];
}


- (void)webView:(WebView *)wv didClearWindowObject:(WebScriptObject *)wso forFrame:(WebFrame *)frame {
    //if (frame != [webView mainFrame]) return;

    // set window.fluid object
    DOMAbstractView *window = (DOMAbstractView *)[webView windowScriptObject];
    [window setValue:javaScriptBridge forKey:@"fluid"];
    
    [self postNotificationName:FUTabControllerDidClearWindowObjectNotification];

    // must get the doc this way. using -[WebView mainFrameDocument] sometimes returns nil here. dunno why.
    DOMDocument *doc = [window document];
    [doc addEventListener:@"DOMContentLoaded" listener:self useCapture:NO];
}


- (void)handleEvent:(DOMEvent *)evt {
    DOMAbstractView *window = (DOMAbstractView *)[webView windowScriptObject];
    DOMDocument *doc = [window document];
    [doc removeEventListener:@"DOMContentLoaded" listener:self useCapture:NO];
    
    [self postNotificationName:FUTabControllerDidLoadDOMContentNotification];
}


#pragma mark -
#pragma mark WebPolicyDelegate

- (void)webView:(WebView *)wv decidePolicyForNavigationAction:(NSDictionary *)info request:(NSURLRequest *)req frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    WebNavigationType navType = [[info objectForKey:WebActionNavigationTypeKey] integerValue];
    
    if (![self shouldHandleRequest:req]) {
        [listener ignore];
        return;
    }
    
    if ([WebView _canHandleRequest:req]) {
        FUActivation *act = [FUActivation activationFromWebActionInfo:info];
        if (act.isCommandKeyPressed) {
            [listener ignore];
            [windowController handleCommandClick:act URL:[[req URL] absoluteString]];
        } else {
            [listener use];
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


- (void)webView:(WebView *)wv decidePolicyForNewWindowAction:(NSDictionary *)info request:(NSURLRequest *)req newFrameName:(NSString *)name decisionListener:(id<WebPolicyDecisionListener>)listener {

    if (![self shouldHandleRequest:req]) {
        [listener ignore];
        return;
    }
    
    FUActivation *act = [FUActivation activationFromWebActionInfo:info];
    if (act.isCommandKeyPressed) {
        [listener ignore];
        [windowController handleCommandClick:act URL:[[req URL] absoluteString]];
    } else if ([[FUUserDefaults instance] targetedClicksCreateTabs]) {
        [[[FUDocumentController instance] frontWindowController] loadURL:[[req URL] absoluteString] inNewTabAndSelect:YES];
    } else {
        // look for existing frame with this name. if found, use it
        FUTabController *tc = nil;
        WebFrame *existingFrame = [[FUDocumentController instance] findFrameNamed:name outTabController:&tc];
        
        if (existingFrame) {
            // found an existing frame with frameName. use it, and suppress new window creation
            [[tc.view window] makeKeyAndOrderFront:self];
            [[[FUDocumentController instance] frontWindowController] selectTabController:tc];

            [existingFrame loadRequest:req];
            [listener ignore];
        } else {
            // no existing frame for name. allow a new window to be created
            [listener use];
        }
    }
}


- (void)webView:(WebView *)wv decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)req frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    id response = [[frame provisionalDataSource] response];
    
    if (response && [response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *headers = [response allHeaderFields];
        
        NSString *contentDisposition = [[headers objectForKey:@"Content-Disposition"] lowercaseString];
        if (contentDisposition && NSNotFound != [contentDisposition rangeOfString:@"attachment"].location) {
            if (![[[req URL] absoluteString] hasSuffix:@".user.js"]) { // don't download userscripts
                [listener download];
                return;
            }
        }
        
        NSString *contentType = [[headers objectForKey:@"Content-Type"] lowercaseString];
        if (contentType && NSNotFound != [contentType rangeOfString:@"application/octet-stream"].location) {
            [listener download];
            return;
        }
    }
    
    if ([[req URL] isFileURL]) {
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[[req URL] path] isDirectory:&isDir];
        
        if (isDir) {
            [listener ignore];
        } else if ([WebView canShowMIMEType:type]) {
            [listener use];
        } else{
            [listener ignore];
        }
    } else if ([WebView canShowMIMEType:type]) {
        [listener use];
    } else {
        [listener download];
    }
}


- (void)webView:(WebView *)sender unableToImplementPolicyWithError:(NSError *)error frame:(WebFrame *)frame {
    NSLog(@"called unableToImplementPolicyWithError:%@ inFrame:%@", error, frame);
}


#pragma mark -
#pragma mark WebQuotaDelegate

#if FU_LOCAL_STORAGE_ENABLED
- (void)webView:(WebView *)wv frame:(WebFrame *)frame exceededDatabaseQuotaForSecurityOrigin:(WebSecurityOrigin *)origin database:(NSString *)databaseIdentifier {
    [origin setQuota:500 * 1024 * 1024];
}
#endif


#pragma mark -
#pragma mark WebUIDelegate

//- (void)webView:(WebView *)wv decidePolicyForGeolocationRequestFromOrigin:(WebSecurityOrigin *)origin frame:(WebFrame *)frame listener:(id <WebGeolocationPolicyListener>)listener {
//    NSString *site = [[[[frame dataSource] mainResource] URL] host];
//    NSString *text = [NSString stringWithFormat:NSLocalizedString(@"The site '%@' would like to use your current location.", @""), site];
//    NSString *button = NSLocalizedString(@"Allow", @"");
//    NSString *altButton = NSLocalizedString(@"Don't Allow", @"");
//    NSWindow *win = [wv window];
//    NSAlert *alert = [NSAlert alertWithMessageText:text defaultButton:button alternateButton:altButton otherButton:nil informativeTextWithFormat:@""];
//    [alert beginSheetModalForWindow:win modalDelegate:self didEndSelector:@selector(geolocationAlertDidEnd:returnCode:contextInfo:) contextInfo:[listener retain]]; // retained
//}
//
//
//- (void)geolocationAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(id <WebGeolocationPolicyListener>)listener {
//    [listener autorelease]; // released
//    if (NSAlertDefaultReturn == returnCode) {
//        [listener allow];
//    } else {
//        [listener deny];
//    }
//}


- (WebView *)webView:(WebView *)wv createWebViewWithRequest:(NSURLRequest *)req {
    FUDestinationType type = [[FUUserDefaults instance] targetedClicksCreateTabs] ? FUDestinationTypeTab : FUDestinationTypeWindow;
    FUTabController *tc = [[FUDocumentController instance] loadURL:[[req URL] absoluteString] destinationType:type inForeground:YES]; // TODO this is supposed to be created offscreen in the background according to webkit docs
    return [tc webView];
}


- (void)webViewShow:(WebView *)wv {
    NSWindow *win = [wv window];
    FUWindowController *wc = [[[FUDocumentController instance] documentForWindow:win] windowController];
    
    [wc selectTabController:[wc tabControllerForWebView:wv]];
    [win makeKeyAndOrderFront:wv];
}


- (void)webViewClose:(WebView *)wv {
    FUTabController *tc = [windowController tabControllerForWebView:wv];
    [windowController removeTabController:tc];
}


- (void)webViewFocus:(WebView *)wv {
    FUTabController *tc = [windowController tabControllerForWebView:wv];
    [windowController selectTabController:tc];
}


- (NSResponder *)webViewFirstResponder:(WebView *)wv {
    return [[wv window] firstResponder];
}


- (void)webView:(WebView *)wv makeFirstResponder:(NSResponder *)responder {
    [[webView window] makeFirstResponder:responder];
}


- (void)webView:(WebView *)wv setStatusText:(NSString *)text {
    self.statusText = text;
}


- (NSString *)webViewStatusText:(WebView *)wv {
    return self.statusText;
}


- (BOOL)webViewAreToolbarsVisible:(WebView *)wv {
    return [[[wv window] toolbar] isVisible];
}


- (void)webView:(WebView *)wv setToolbarsVisible:(BOOL)visible {
    if (![[FUUserDefaults instance] targetedClicksCreateTabs]) {
        [[[wv window] toolbar] setVisible:visible];
    }
}


- (BOOL)webViewIsStatusBarVisible:(WebView *)wv {
    return [[FUUserDefaults instance] statusBarShown];
}


- (void)webView:(WebView *)wv setStatusBarVisible:(BOOL)visible {
    if (![[FUUserDefaults instance] targetedClicksCreateTabs]) {
        [[FUUserDefaults instance] setStatusBarShown:visible];
    }
}


- (BOOL)webViewIsResizable:(WebView *)wv {
    // TODO
    return YES;
}


- (void)webView:(WebView *)wv setResizable:(BOOL)resizable {
    if (![[FUUserDefaults instance] targetedClicksCreateTabs]) {
        // TODO
    }
}


- (void)webView:(WebView *)wv setFrame:(NSRect)frame {
    if (![[FUUserDefaults instance] targetedClicksCreateTabs]) {
        windowController.suppressNextFrameStringSave = YES;
        [[windowController window] setFrame:frame display:YES];
    }
}


- (NSRect)webViewFrame:(WebView *)wv {
    return [[wv window] frame];
}


- (void)alertPanelDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)ctx {
    
}


- (void)webView:(WebView *)wv runJavaScriptAlertPanelWithMessage:(NSString *)msg initiatedByFrame:(WebFrame *)frame {
    NSString *tit = NSLocalizedString(@"JavaScript", @"");
    NSString *defaultButton = NSLocalizedString(@"OK", @"");

    //NSRunInformationalAlertPanel(title, msg, defaultButton, nil, nil);
    
    self.currentJavaScriptAlert = [NSAlert alertWithMessageText:tit defaultButton:defaultButton alternateButton:nil otherButton:nil informativeTextWithFormat:msg];
    [currentJavaScriptAlert beginSheetModalForWindow:[[frame webView] window] modalDelegate:self didEndSelector:@selector(alertPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}


- (BOOL)webView:(WebView *)wv runJavaScriptConfirmPanelWithMessage:(NSString *)msg initiatedByFrame:(WebFrame *)frame {
    NSInteger result = NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),  // title
                                                    msg,                                    // message
                                                    NSLocalizedString(@"OK", @""),          // default button
                                                    NSLocalizedString(@"Cancel", @""),      // alt button
                                                    nil);
    return NSAlertDefaultReturn == result;    
}


- (NSString *)webView:(WebView *)wv runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WebFrame *)frame {
    NSString *nibName = @"FUPromptView";
    NSNib *nib = [[[NSNib alloc] initWithNibNamed:nibName bundle:[NSBundle mainBundle]] autorelease];
    if (![nib instantiateNibWithOwner:self topLevelObjects:nil]) {
        NSLog(@"Could not load nib named %@ in %s", nibName, __PRETTY_FUNCTION__);
        return nil;
    }
    
    self.promptResultText = defaultText;
    
    self.currentJavaScriptAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript", @"")
                                                  defaultButton:NSLocalizedString(@"OK", @"")
                                                alternateButton:NSLocalizedString(@"Cancel", @"")
                                                    otherButton:nil
                                      informativeTextWithFormat:prompt];

    [promptTextView setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];

    [currentJavaScriptAlert setAccessoryView:promptView];
    [[currentJavaScriptAlert window] makeFirstResponder:promptTextView];
    [promptTextView selectAll:nil];

    // run
    NSInteger result = [currentJavaScriptAlert runModal];
    
    if (NSAlertDefaultReturn == result) {
        return promptResultText;
    } else {
        return nil;
    }
}


- (BOOL)webView:(WebView *)wv runBeforeUnloadConfirmPanelWithMessage:(NSString *)msg initiatedByFrame:(WebFrame *)frame {
    NSInteger result = NSRunInformationalAlertPanel(NSLocalizedString(@"JavaScript", @""),  // title
                                                    msg,                                    // message
                                                    NSLocalizedString(@"OK", @""),          // default button
                                                    NSLocalizedString(@"Cancel", @""),      // alt button
                                                    nil);
    return NSAlertDefaultReturn == result;    
}


- (void)webView:(WebView *)wv runOpenPanelForFileButtonWithResultListener:(id <WebOpenPanelResultListener>)listener {
#ifdef FAKE
    if ([fileChooserPath length]) {
        [listener chooseFilename:fileChooserPath];
        return;
    }
#endif
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetForDirectory:nil 
                                 file:nil 
                       modalForWindow:[self.view window]
                        modalDelegate:self
                       didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                          contextInfo:[listener retain]]; // retained
}


- (NSArray *)webView:(WebView *)wv contextMenuItemsForElement:(NSDictionary *)info defaultMenuItems:(NSArray *)defaultItems {        
    NSMutableArray *items = [NSMutableArray arrayWithArray:defaultItems];
    id removeMe = nil;
    
    for (id item in items) {        
        NSInteger t = [item tag];
        
        if (WebMenuItemTagOpenLinkInNewWindow == t) {
            [item setTarget:self];
            [item setAction:@selector(openLinkInNewWindowFromMenu:)];
            [item setRepresentedObject:info];
        } else if (WebMenuItemTagOpenFrameInNewWindow == t) {
            [item setTarget:self];
            [item setAction:@selector(openFrameInNewWindowFromMenu:)];
            [item setRepresentedObject:info];
        } else if (WebMenuItemTagOpenImageInNewWindow == t) {
            [item setTarget:self];
            [item setAction:@selector(openImageInNewWindowFromMenu:)];
            [item setRepresentedObject:info];
        } else if (WebMenuItemTagSearchWeb == t) {
            [item setTarget:self];
            [item setAction:@selector(searchWebFromMenu:)];
            [item setRepresentedObject:info];
        } else if ([NSLocalizedString(@"Open Link", @"") isEqualToString:[item title]]) {
            removeMe = item;
        }
    }
    
    if (removeMe) {
        [items removeObject:removeMe];
    }
    
    
    NSString *linkURLString = [[info objectForKey:WebElementLinkURLKey] absoluteString];
    if ([linkURLString length]) {
        
        BOOL tabbedBrowsingEnabled = [[FUUserDefaults instance] tabbedBrowsingEnabled];
        if (tabbedBrowsingEnabled) {
            NSMenuItem *openInNewTabItem = [[[NSMenuItem alloc] init] autorelease];
            [openInNewTabItem setTitle:NSLocalizedString(@"Open Link in New Tab", @"")];
            [openInNewTabItem setTarget:self];
            [openInNewTabItem setAction:@selector(openLinkInNewTabFromMenu:)];
            [openInNewTabItem setRepresentedObject:info];
            [items insertObject:openInNewTabItem atIndex:0];
        }
        
        [items insertObject:[NSMenuItem separatorItem] atIndex:2];
        
        NSMenuItem *downloadAsItem = [[[NSMenuItem alloc] init] autorelease];
        [downloadAsItem setTitle:NSLocalizedString(@"Download Linked File As…", @"")];
        [downloadAsItem setTarget:self];
        [downloadAsItem setAction:@selector(downloadLinkAsFromMenu:)];
        [downloadAsItem setRepresentedObject:info];
        [self insertItem:downloadAsItem intoMenuItems:items afterItemWithTag:WebMenuItemTagDownloadLinkToDisk];
    }
    
    return items;
}


- (void)webView:(WebView *)wv mouseDidMoveOverElement:(NSDictionary *)info modifierFlags:(NSUInteger)flags {    
    NSURL *URL = [info valueForKey:WebElementLinkURLKey];
    
    if (URL) {
        WebFrame *sourceFrame = [info valueForKey:WebElementFrameKey];
        WebFrame *targetFrame = [info valueForKey:WebElementLinkTargetFrameKey];
        DOMNode  *targetNode  = [info valueForKey:WebElementDOMNodeKey];
        DOMElement *anchorEl  = [targetNode firstAncestorOrSelfByTagName:@"a"];
        NSString *targetStr   = [anchorEl getAttribute:@"target"];
        NSString *format = nil;
        
        if (sourceFrame != targetFrame) {
            if ([targetStr length] && ([targetStr isEqualToString:@"_new"] || [targetStr isEqualToString:@"_blank"])) {
                format = NSLocalizedString(@"Open \"%@\" in a new window", @"");
            } else {
                format = NSLocalizedString(@"Open \"%@\" in a new frame", @"");
            }
        } else if ([[URL scheme] hasPrefix:@"javascript"]) {
            format = NSLocalizedString(@"Run script \"%@\"", @"");
        } else {
            format = NSLocalizedString(@"Go to \"%@\"", @"");
        }
        
        self.statusText = [NSString stringWithFormat:format, [URL absoluteString]];
    } else {
        self.statusText = @"";
    }
}

#pragma mark -
#pragma mark WebProgressNotifications

- (void)webViewProgressStarted:(NSNotification *)n {
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"isProcessing"];
    self.statusText = NSLocalizedString(@"Loading...", @"");
    [self postNotificationName:FUTabControllerProgressDidStartNotification];
}


- (void)webViewProgressEstimateChanged:(NSNotification *)n {
    if ([URLString length]) {
        self.statusText = [NSString stringWithFormat:NSLocalizedString(@"Loading \"%@\"", @""), URLString];
    } else {
        self.statusText = NSLocalizedString(@"Loading...", @"");
    }
    
    [self postNotificationName:FUTabControllerProgressDidChangeNotification];
}


- (void)webViewProgressFinished:(NSNotification *)n {
    [self setValue:[NSNumber numberWithBool:NO] forKey:@"isProcessing"];
    [self postNotificationName:FUTabControllerProgressDidFinishNotification];
    self.statusText = @"";
}


#pragma mark -
#pragma mark Private

- (void)setUpWebView {
    // delegates
    [webView setResourceLoadDelegate:self];
    [webView setFrameLoadDelegate:self];
    [webView setPolicyDelegate:self];
    [webView setUIDelegate:self];
    // downloadDelegate set in -[FUWebView initWithFrame:] cuz it's always the same

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(webViewProgressStarted:) name:WebViewProgressStartedNotification object:webView];
    [nc addObserver:self selector:@selector(webViewProgressEstimateChanged:) name:WebViewProgressEstimateChangedNotification object:webView];
    [nc addObserver:self selector:@selector(webViewProgressFinished:) name:WebViewProgressFinishedNotification object:webView];
}


- (BOOL)willRetryWithTLDAdded:(WebView *)wv {
    NSString *host = [[NSURL URLWithString:[wv mainFrameURL]] host];
    
    NSString *s = nil;
    if (![host hasTLDSuffix]) {
        s = [host stringByEnsuringTLDSuffix];
    }
    
    if ([s length]) {
        [self loadURL:s];
        return YES;
    } else {
        return NO;
    }
}


- (void)handleLoadFail:(NSError *)err {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          err, FUErrorKey,
                          [err localizedDescription], FUErrorDescriptionKey,
                          nil];
    [self postNotificationName:FUTabControllerDidFailLoadNotification userInfo:info];

    NSInteger code = [err code];
    
    // WebKitErrorPlugInWillHandleLoad 204
    if (NSURLErrorCancelled == code || WebKitErrorFrameLoadInterruptedByPolicyChange == code || 204 == code) {
        return;
    }
    
    self.lastLoadFailed = YES;
    
    [self setValue:[NSNumber numberWithBool:NO] forKey:@"isProcessing"];
    self.title = NSLocalizedString(@"Load Failed", @"");
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"LoadFailed" ofType:@"html"];
    NSString *source = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:path] encoding:NSUTF8StringEncoding error:nil];
    source = [NSString stringWithFormat:source, [err localizedDescription]];
    
    NSURL *failingURL = [[[[webView mainFrame] provisionalDataSource] initialRequest] URL];
    NSString *failingURLString = [failingURL absoluteString];
    
    [[webView mainFrame] loadAlternateHTMLString:source baseURL:nil forUnreachableURL:failingURL];
    [self performSelector:@selector(setURLString:) withObject:failingURLString afterDelay:0];
    
    [[FURecentURLController instance] removeRecentURL:failingURLString];
}


- (NSImage *)defaultFavicon {
    return [[WebIconDatabase sharedIconDatabase] defaultFavicon];
}


- (void)postNotificationName:(NSString *)name {
    [self postNotificationName:name userInfo:nil];
}


- (void)postNotificationName:(NSString *)name userInfo:(NSDictionary *)additionalInfo {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInteger:[windowController indexOfTabController:self]], FUIndexKey,
                                     nil];
    [userInfo addEntriesFromDictionary:additionalInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
}


- (BOOL)shouldHandleRequest:(NSURLRequest *)inReq {
    NSURLRequest *req = [[FUHandlerController instance] requestForRequest:inReq];

        // if there's a special scheme handler for inReq, return the final req to be handled
    if (req != inReq) {
        [[webView mainFrame] loadRequest:req];
        return NO;
        
        // else if the url is whitelisted, return YES for it be handled
    } else if ([[FUWhitelistController instance] processRequest:inReq]) {
        return YES;
        
        // else return NO to signal don't handle
    } else {
        return NO;
    }
}


- (BOOL)insertItem:(NSMenuItem *)item intoMenuItems:(NSMutableArray *)items afterItemWithTag:(NSInteger)tag {
    NSInteger i = [self indexOfItemWithTag:tag inMenuItems:items];
    if (NSNotFound == i) {
        [items addObject:item];
        return NO;
    } else {
        [items insertObject:item atIndex:i + 1];
        return YES;
    }
}


- (NSInteger)indexOfItemWithTag:(NSUInteger)tag inMenuItems:(NSArray *)items {
    NSInteger i = 0;
    for (NSMenuItem *item in items) {
        if ([item tag] == tag) return i; 
        i++;
    }
    return NSNotFound;
}


- (NSString *)currentSelectionFromWebView {
    DOMRange *r = [webView selectedDOMRange];
    return [r text];
}


- (void)openPanelDidEnd:(NSSavePanel *)openPanel returnCode:(NSInteger)code contextInfo:(id <WebOpenPanelResultListener>)listener {
    [listener autorelease]; // released

    if (NSOKButton == code) {
        [listener chooseFilename:[openPanel filename]];
    }
}


- (void)savePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)code contextInfo:(NSURL *)URL {
    [URL autorelease]; // released
    
    if (NSFileHandlingPanelCancelButton == code) {
        return;
    }
    
    NSURLRequest *req = [NSURLRequest requestWithURL:URL];
    NSString *dirPath = [[savePanel directory] stringByExpandingTildeInPath];
    NSString *filename = [[savePanel filename] lastPathComponent];

    [[FUDocumentController instance] downloadRequest:req directory:dirPath filename:filename];
}

@synthesize windowController;
@synthesize view;
@synthesize webView;
@synthesize javaScriptBridge;
@synthesize title;
@synthesize URLString;
@synthesize initialURLString;
@synthesize favicon;
@synthesize inspector;
@synthesize statusText;
@synthesize promptResultText;
@synthesize promptView;
@synthesize promptTextView;
@synthesize lastLoadFailed;
@synthesize isProcessing;
@synthesize canReload;
@synthesize suspendedCommand;
@synthesize currentJavaScriptAlert;
#ifdef FAKE
@synthesize autoTyper;
@synthesize fileChooserPath;
#endif    
@end
