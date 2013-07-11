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

#import "FUStopLoadingCommand.h"
#import "FUDocumentController.h"
#import "FUTabController+Scripting.h"

@implementation FUStopLoadingCommand

- (id)performDefaultImplementation {
    NSDictionary *args = [self evaluatedArguments];
    
    FUTabController *tc = [args objectForKey:@"tabController"]; // may be nil
    if (!tc) {
        tc = [[FUDocumentController instance] frontTabController];
    }
    [tc handleStopLoadingCommand:self];
    
    return nil;
}

@end
