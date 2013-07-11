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

#import "FUHandlerPreferences.h"
#import "FUHandlerController.h"

@implementation FUHandlerPreferences

- (void)dealloc {
    self.arrayController = nil;
    self.handlers = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    [self loadHandlers];
}


- (void)insertObject:(NSMutableDictionary *)dict inHandlersAtIndex:(NSInteger)i {
    NSUndoManager *undoManager = [[[self controlBox] window] undoManager];
    [[undoManager prepareWithInvocationTarget:self] removeObjectFromHandlersAtIndex:i];
    
    [self startObservingRule:dict];
    [handlers insertObject:dict atIndex:i];
    [self storeHandlers];
}


- (void)removeObjectFromHandlersAtIndex:(NSInteger)i {
    NSMutableDictionary *rule = [self.handlers objectAtIndex:i];
    
    NSUndoManager *undoManager = [[[self controlBox] window] undoManager];
    [[undoManager prepareWithInvocationTarget:self] insertObject:rule inHandlersAtIndex:i];
    
    [self stopObservingRule:rule];
    [self.handlers removeObjectAtIndex:i];
    [self storeHandlers];
}


- (void)startObservingRule:(NSMutableDictionary *)rule {
    [rule addObserver:self
           forKeyPath:@"scheme"
              options:NSKeyValueObservingOptionOld
              context:NULL];
    [rule addObserver:self
           forKeyPath:@"URLString"
              options:NSKeyValueObservingOptionOld
              context:NULL];
}


- (void)stopObservingRule:(NSMutableDictionary *)rule {
    [rule removeObserver:self forKeyPath:@"scheme"];
    [rule removeObserver:self forKeyPath:@"URLString"];
}


- (void)changeKeyPath:(NSString *)keyPath ofObject:(id)obj toValue:(id)v {
    [obj setValue:v forKeyPath:keyPath];
    [self storeHandlers];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj change:(NSDictionary *)change context:(void *)ctx {
    NSUndoManager *undoManager = [[[self controlBox] window] undoManager];
    id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
    [[undoManager prepareWithInvocationTarget:self] changeKeyPath:keyPath ofObject:obj toValue:oldValue];
    [self storeHandlers];
}


- (void)controlTextDidEndEditing:(NSNotification *)n {
    [self storeHandlers];
}


- (void)loadHandlers {
    self.handlers = [[FUHandlerController instance] handlers];
}


- (void)storeHandlers {
    [[FUHandlerController instance] setHandlers:handlers];
    [[FUHandlerController instance] save];
}


- (void)setHandlers:(NSMutableArray *)new {
    NSMutableArray *old = handlers;
    
    if (old != new) {
        for (id rule in old) {
            [self stopObservingRule:rule];
        }
        
        [old autorelease];
        handlers = [new retain];
        [self storeHandlers];
        
        for (id rule in new) {
            [self startObservingRule:rule];
        }
    }
}

@synthesize arrayController;
@synthesize handlers;
@end
