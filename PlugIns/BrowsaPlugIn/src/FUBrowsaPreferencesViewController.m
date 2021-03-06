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

#import "FUBrowsaPreferencesViewController.h"
#import <Fluidium/FUPlugInAPI.h>
#import "FUBrowsaPlugIn.h"
#import "FUBrowsaViewController.h"
#import <WebKit/WebKit.h>
#import <Fluidium/FUUtils.h>

@interface FUBrowsaPreferencesViewController ()
- (void)loadUserAgentStrings;
- (void)updateMenu;
- (BOOL)isUsingDefaultUserAgent;
- (void)customUserAgentSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(void *)ctx;

@property (nonatomic, copy) NSArray *userAgentStrings;
@property (nonatomic, copy) NSString *defaultUserAgentFormat;
@end

@implementation FUBrowsaPreferencesViewController

- (id)initWithPlugIn:(FUBrowsaPlugIn *)p {
    if ([super initWithNibName:@"FUBrowsaPreferencesView" bundle:[NSBundle bundleForClass:[self class]]]) {
        self.plugIn = p;
        [self loadUserAgentStrings];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.editUserAgentSheet = nil;
    self.userAgentPopUpButton = nil;
    self.plugIn = nil;

    self.userAgentString = nil;
    self.userAgentStrings = nil;
    self.defaultUserAgentFormat = nil;
    self.editingUserAgentString = nil;
    [super dealloc];
}


- (id)retain {
    return [super retain];
}


- (void)awakeFromNib {
    [self updateMenu];
}


#pragma mark -
#pragma mark Actions

- (IBAction)showNavBars:(id)sender {
    NSInteger showNavbar = plugIn.showNavBar;
    
    for (FUBrowsaViewController *vc in plugIn.viewControllers) {
        if (FUBrowsaShowNavBarAlways == showNavbar) {
            [vc showNavBar:sender];
        } else {
            [vc hideNavBar:sender];
        }
    }    
}


- (IBAction)changeUserAgentString:(id)sender {
    NSMenu *UAMenu = [sender menu];
    
    for (NSMenuItem *item in [UAMenu itemArray]) {
        [item setState:NSOffState];
    }
    
    [sender setState:NSOnState];
    
    self.userAgentString = [[userAgentStrings objectAtIndex:[sender tag]] objectForKey:@"value"];
}


- (IBAction)changeUserAgentStringToOther:(id)sender {
    NSMenu *UAMenu = [sender menu];
    
    for (NSMenuItem *item in [UAMenu itemArray]) {
        [item setState:NSOffState];
    }
    
    [sender setState:NSOnState];
    
    self.editingUserAgentString = self.userAgentString;
    
    [NSApp beginSheet:editUserAgentSheet
       modalForWindow:[self.view window]
        modalDelegate:self
       didEndSelector:@selector(customUserAgentSheetDidEnd:returnCode:contextInfo:) 
          contextInfo:NULL];
}


- (IBAction)endEditUserAgentSheet:(id)sender {
    [NSApp endSheet:editUserAgentSheet returnCode:[sender tag]];
    [editUserAgentSheet orderOut:sender];
}


#pragma mark -
#pragma mark Private

- (void)loadUserAgentStrings {
    self.userAgentStrings = [plugIn.plugInAPI allUserAgentStrings];
    if ([userAgentStrings count]) {
        self.defaultUserAgentFormat = [[userAgentStrings objectAtIndex:0] objectForKey:@"value"];
    }
}


- (NSString *)userAgentString {
    if ([self isUsingDefaultUserAgent]) {
        return [plugIn.plugInAPI defaultUserAgentString];
    } else {
        return plugIn.userAgentString;
    }
}


- (void)setUserAgentString:(NSString *)s {
    if ([s isEqualToString:defaultUserAgentFormat]) {
        plugIn.userAgentString = nil;
    } else {
        plugIn.userAgentString = [[s copy] autorelease];
    }

    [[NSUserDefaults standardUserDefaults] synchronize];

    [plugIn postBrowsaUserAgentStringDidChangeNotification];
}


- (BOOL)isUsingDefaultUserAgent {
    if ([plugIn.userAgentString length]) {
        return NO;
    } else{
        return YES;
    }
}


- (void)updateMenu {
    NSString *currentUAString = nil;
    if ([self isUsingDefaultUserAgent]) {
        currentUAString = self.defaultUserAgentFormat;
    } else {
        currentUAString = self.userAgentString;
    }

    NSMenu *UAMenu = [[[NSMenu alloc] init] autorelease];
    [userAgentPopUpButton setMenu:UAMenu];
    
    NSString *lastTitleFirstWord = nil;
    NSInteger tag = 0;
    NSInteger selectedIndex = -1;
    for (NSDictionary *d in userAgentStrings) {
        NSString *title = [d objectForKey:@"title"];
        NSString *value = [d objectForKey:@"value"];
        
        if (lastTitleFirstWord && ![title hasPrefix:lastTitleFirstWord]) {
            [UAMenu addItem:[NSMenuItem separatorItem]];
        }
        
        NSInteger loc = [title rangeOfString:@" "].location;
        if (NSNotFound == loc) {
            loc = [title length];
        }
        lastTitleFirstWord = [title substringToIndex:loc];
        
        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title
                                                       action:@selector(changeUserAgentString:)
                                                keyEquivalent:@""] autorelease];
        [item setTarget:self];
        [item setTag:tag];
        [UAMenu addItem:item];
        
        if (-1 == selectedIndex && [currentUAString isEqualToString:value]) {
            [item setState:NSOnState];
            selectedIndex = tag;
        }
        
        tag++;
    }
    
    [UAMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *otherItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other...", @"")
                                                        action:@selector(changeUserAgentStringToOther:)
                                                 keyEquivalent:@""] autorelease];
    [otherItem setTag:tag];
    [otherItem setTarget:self];
    [UAMenu addItem:otherItem];
    
    if (-1 == selectedIndex) {
        [otherItem setState:NSOnState];
        selectedIndex = [otherItem tag];
    }
    
    [userAgentPopUpButton selectItemWithTag:selectedIndex];
}


- (void)customUserAgentSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(void *)ctx {
    if (NSOKButton == code) {
        self.userAgentString = self.editingUserAgentString;
    }
    self.editingUserAgentString = nil;
}

@synthesize editUserAgentSheet;
@synthesize userAgentPopUpButton;
@synthesize plugIn;
@synthesize userAgentString;
@synthesize userAgentStrings;
@synthesize defaultUserAgentFormat;
@synthesize editingUserAgentString;
@end
