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

#import "FUCreateCommand.h"
#import "FUDocumentController+Scripting.h"
#import "FUDocument.h"
#import "FUDocument+Scripting.h"
#import "FUWindowController.h"
#import "FUTabController.h"

@implementation FUCreateCommand

- (id)performDefaultImplementation {
    NSDictionary *args = [self evaluatedArguments];
    FourCharCode cls = [[args objectForKey:@"ObjectClass"] integerValue];
    
    // make new browser window
    if ([FUDocument classCode] == cls) {

        [NSApp sendAction:@selector(script_newDocument:) to:nil from:nil];
        return [[[FUDocumentController instance] frontDocument] objectSpecifier];
        
    } 
    
    // make new tab
    else if ([FUTabController classCode] == cls) {
        FUDocument *target = [args objectForKey:@"document"]; // may be nil
        if (!target) {
            target = [[FUDocumentController instance] frontDocument];
        }        
        return [target handleCreateCommand:self];
    } 
    
    // make something else
    else {
        return [super performDefaultImplementation];
    }
    
}

@end
