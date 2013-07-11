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

#import "FUTabController.h"

@interface FUTabController (Scripting)

// Properties
- (NSUInteger)orderedIndex;
- (BOOL)isSelected;

// command helper
- (void)suspendCommand:(NSScriptCommand *)cmd;
- (void)resumeSuspendedCommandAfterDelay:(NSTimeInterval)delay;
- (void)suspendExecutionUntilProgressFinishedWithCommand:(NSScriptCommand *)cmd;

// Commands
- (id)handleCloseCommand:(NSCloseCommand *)cmd;

- (id)handleDispatchMouseEventCommand:(NSScriptCommand *)cmd;
- (id)handleDispatchKeyboardEventCommand:(NSScriptCommand *)cmd;

- (id)handleGoBackCommand:(NSScriptCommand *)cmd;
- (id)handleGoForwardCommand:(NSScriptCommand *)cmd;
- (id)handleGoHomeCommand:(NSScriptCommand *)cmd;
- (id)handleReloadCommand:(NSScriptCommand *)cmd;
- (id)handleStopLoadingCommand:(NSScriptCommand *)cmd;
- (id)handleZoomInCommand:(NSScriptCommand *)cmd;
- (id)handleZoomOutCommand:(NSScriptCommand *)cmd;
- (id)handleActualSizeCommand:(NSScriptCommand *)cmd;

- (id)handleLoadURLCommand:(NSScriptCommand *)cmd;
- (id)handleDoJavaScriptCommand:(NSScriptCommand *)cmd;
- (id)handleDismissDialogCommand:(NSScriptCommand *)cmd;
- (id)handleClickLinkCommand:(NSScriptCommand *)cmd;
- (id)handleClickButtonCommand:(NSScriptCommand *)cmd;
- (id)handleSetElementValueCommand:(NSScriptCommand *)cmd;
- (id)handleFocusElementCommand:(NSScriptCommand *)cmd;
- (id)handleSubmitFormCommand:(NSScriptCommand *)cmd;
- (id)handleSetFormValuesCommand:(NSScriptCommand *)cmd;
- (id)handleCaptureWebPageCommand:(NSScriptCommand *)cmd;
- (id)handleSetVariableValueCommand:(NSScriptCommand *)cmd;

- (id)handleAssertCommand:(NSScriptCommand *)cmd;
- (id)handleAssertTitleEqualsCommand:(NSScriptCommand *)cmd;
- (id)handleAssertStatusCodeEqualsCommand:(NSScriptCommand *)cmd;
- (id)handleAssertStatusCodeNotEqualCommand:(NSScriptCommand *)cmd;
- (id)handleAssertHasElementWithIdCommand:(NSScriptCommand *)cmd;
- (id)handleAssertDoesntHaveElementWithIdCommand:(NSScriptCommand *)cmd;
- (id)handleAssertHasElementForXPathCommand:(NSScriptCommand *)cmd;
- (id)handleAssertDoesntHaveElementForXPathCommand:(NSScriptCommand *)cmd;
- (id)handleAssertContainsTextCommand:(NSScriptCommand *)cmd;
- (id)handleAssertDoesntContainTextCommand:(NSScriptCommand *)cmd;
- (id)handleAssertJavaScriptEvalsTrueCommand:(NSScriptCommand *)cmd;
- (id)handleAssertXPathEvalsTrueCommand:(NSScriptCommand *)cmd;

- (id)handleWaitForConditionCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionPageTitleEquals:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionHasElementWithIdCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionDoesntHaveElementWithIdCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionContainsTextCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionDoesntContainTextCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionContainsHTMLCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionDoesntContainHTMLCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionJavaScriptEvalsTrueCommand:(NSScriptCommand *)cmd;
//- (id)handleWaitForConditionJavaScriptEvalsFalseCommand:(NSScriptCommand *)cmd;
@end
