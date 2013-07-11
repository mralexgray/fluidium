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

#import "FUUserthingViewController.h"
#import "FUApplication.h"

#define MIN_TABLE_WIDTH 100

@interface FUUserthingViewController ()
- (void)changeKeyPath:(NSString *)keyPath ofObject:(id)obj toValue:(id)inValue;
@end

@implementation FUUserthingViewController

- (id)init {
    return [self initWithNibName:@"FUUserthingView" bundle:nil];
}


- (id)initWithNibName:(NSString *)name bundle:(NSBundle *)b {
    if (self = [super initWithNibName:name bundle:b]) {
        
    }
    return self;
}


- (void)dealloc {
    self.splitView = nil;
    self.arrayController = nil;
    self.textView = nil;
    self.userthings = nil;
    [super dealloc];
}


- (void)awakeFromNib {
    [textView setFont:[NSFont fontWithName:@"Monaco" size:10]];
    [self loadUserthings];
}


- (void)insertObject:(NSMutableDictionary *)dict inUserthingsAtIndex:(NSInteger)i {
    NSUndoManager *undoManager = [[self.view window] undoManager];
    [[undoManager prepareWithInvocationTarget:self] removeObjectFromUserthingsAtIndex:i];
    
    [self startObservingRule:dict];
    [self.userthings insertObject:dict atIndex:i];
    [self storeUserthings];
}


- (void)removeObjectFromUserthingsAtIndex:(NSInteger)i {
    NSMutableDictionary *rule = [self.userthings objectAtIndex:i];
    
    NSUndoManager *undoManager = [[self.view window] undoManager];
    [[undoManager prepareWithInvocationTarget:self] insertObject:rule inUserthingsAtIndex:i];
    
    [self stopObservingRule:rule];
    [self.userthings removeObjectAtIndex:i];
    [self storeUserthings];
}


- (void)startObservingRule:(NSMutableDictionary *)rule {
    [rule addObserver:self
           forKeyPath:@"URLPattern"
              options:NSKeyValueObservingOptionOld
              context:NULL];
    [rule addObserver:self
           forKeyPath:@"source"
              options:NSKeyValueObservingOptionOld
              context:NULL];
    [rule addObserver:self
           forKeyPath:@"enabled"
              options:NSKeyValueObservingOptionOld
              context:NULL];
}


- (void)stopObservingRule:(NSMutableDictionary *)rule {
    [rule removeObserver:self forKeyPath:@"URLPattern"];
    [rule removeObserver:self forKeyPath:@"source"];
    [rule removeObserver:self forKeyPath:@"enabled"];
}


- (void)changeKeyPath:(NSString *)keyPath ofObject:(id)obj toValue:(id)v {
    [obj setValue:v forKeyPath:keyPath];
    [self storeUserthings];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj change:(NSDictionary *)change context:(void *)ctx {
    NSUndoManager *undoManager = [[self.view window] undoManager];
    id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
    [[undoManager prepareWithInvocationTarget:self] changeKeyPath:keyPath ofObject:obj toValue:oldValue];
    [self storeUserthings];
}


- (void)controlTextDidEndEditing:(NSNotification *)n {
    [self storeUserthings];
}


#pragma mark -
#pragma mark Abstract

- (void)loadUserthings {
    NSAssert(0, @"abstract method. must override");
}


- (void)storeUserthings {
    NSAssert(0, @"abstract method. must override");
}


- (void)setUserthings:(NSMutableArray *)a {
    NSAssert(0, @"abstract method. must override");
}


#pragma mark -
#pragma mark NSSplitViewDelegate

- (void)splitView:(NSSplitView *)sv resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSArray *views = [sv subviews];
    NSView *leftView = [views objectAtIndex:0];
    NSView *rightView = [views objectAtIndex:1];
    NSRect leftRect = [leftView frame];
    NSRect rightRect = [rightView frame];
                    
    CGFloat dividerThickness = [sv dividerThickness];
    NSRect newFrame = [sv frame];
    
    leftRect.size.height = newFrame.size.height;
	leftRect.origin = NSMakePoint(0, 0);
	rightRect.size.width = newFrame.size.width - leftRect.size.width - dividerThickness;
	rightRect.size.height = newFrame.size.height;
	rightRect.origin.x = leftRect.size.width + dividerThickness;
    
	[leftView setFrame:leftRect];
	[rightView setFrame:rightRect];
}


- (CGFloat)splitView:(NSSplitView *)sv constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)i {
	return MIN_TABLE_WIDTH;
}


- (CGFloat)splitView:(NSSplitView *)sv constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)i {
	return NSWidth([sv frame]) - MIN_TABLE_WIDTH;
}

@synthesize splitView;
@synthesize arrayController;
@synthesize textView;
@synthesize userthings;
@end
