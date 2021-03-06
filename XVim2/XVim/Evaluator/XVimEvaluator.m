//
//  XVimEvaluator.m
//  XVim
//
//  Created by Shuichiro Suzuki on 2/3/12.
//  Copyright 2012 JugglerShu.Net. All rights reserved.
//

#import "XVimEvaluator.h"
#import "XVim.h"
#import "XVimCommandLineEvaluator.h"
#import "XVimKeyStroke.h"
#import "XVimKeymapProvider.h"
#import "XVimNormalEvaluator.h"
#import "XVimRegister.h"
#import "XVimSearch.h"
#import "XVimWindow.h"


static XVimEvaluator* s_invalidEvaluator = nil;
static XVimEvaluator* s_noOperationEvaluator = nil;
static XVimEvaluator* s_popEvaluator = nil;

@implementation XVimEvaluator

@synthesize yankRegister = _yankRegister;
@synthesize numericArg = _numericArg;

+ (void)initialize
{
    if (self == [XVimEvaluator class]) {
        s_invalidEvaluator = [[XVimEvaluator alloc] init];
        s_noOperationEvaluator = [[XVimEvaluator alloc] init];
        s_popEvaluator = [[XVimEvaluator alloc] init];
    }
}

+ (XVimEvaluator*)invalidEvaluator { return s_invalidEvaluator; }

+ (XVimEvaluator*)noOperationEvaluator { return s_noOperationEvaluator; }

+ (XVimEvaluator*)popEvaluator { return s_popEvaluator; }

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (id)initWithWindow:(XVimWindow *)window
{
    NSAssert(nil != window, @"window must not be nil");
    if (self = [super init]) {
        self.window = window;
        self.parent = nil;
        self.argumentString = [[NSMutableString alloc] init];
        self.numericArg = 1;
        self.numericMode = NO;
        self.yankRegister = nil;
        self.onChildCompleteHandler = @selector(onChildComplete:);
    }
    return self;
}

- (void)dealloc { [self endUndoGrouping]; }

- (id<SourceViewProtocol>)sourceView { return self.window.sourceView; }

- (XVimEvaluator*)eval:(XVimKeyStroke*)keyStroke
{
    // This is default implementation of evaluator.
    // Only keyDown events are supposed to be passed here.
    // Invokes each key event handler
    // <C-k> invokes "C_k:" selector

    let handler = keyStroke.selector;
    if ([self respondsToSelector:handler]) {
        //DEBUG_LOG("Calling SELECTOR %@", NSStringFromSelector(handler));
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [self performSelector:handler];
#pragma clang diagnostic pop
    }
    else {
        DEBUG_LOG("SELECTOR %@ not found", NSStringFromSelector(handler));
        return [self defaultNextEvaluator];
    }
}

- (XVimEvaluator*)onChildComplete:(XVimEvaluator*)childEvaluator { return nil; }

- (void)becameHandler { self.sourceView.xvimTextViewDelegate = self; }

- (void)cancelHandler
{
    self.sourceView.xvimTextViewDelegate = nil;
    [self endUndoGrouping];
}

- (void)didEndHandler
{
    self.sourceView.xvimTextViewDelegate = nil;
    [self endUndoGrouping];
}

- (XVimKeymap*)selectKeymapWithProvider:(id<XVimKeymapProvider>)keymapProvider
{
    return [keymapProvider keymapForMode:XVIM_MODE_NORMAL];
}

- (XVimEvaluator*)defaultNextEvaluator { return [XVimEvaluator invalidEvaluator]; }

- (NSString*)modeString { return @""; }

- (XVIM_MODE)mode { return XVIM_MODE_NORMAL; }

- (BOOL)isRelatedTo:(XVimEvaluator*)other { return other == self; }

- (void)resetCompletionHandler { self.onChildCompleteHandler = @selector(onChildComplete:); }

- (XVimEvaluator*)D_d
{
    // This is for debugging purpose.
    // Write any debugging process to confirme some behaviour.
    return nil;
}

- (XVimEvaluator*)ESC { return [XVimEvaluator invalidEvaluator]; }

// Normally argumentString, but can be overridden
- (NSString*)argumentDisplayString { return [self.args componentsJoinedByString:@" "]; }

- (NSArray<NSString*>*)args
{
    var ps = [NSMutableArray<NSString*> new];
    var evaluator = self.parent;
    while (evaluator != nil) {
        let arg = evaluator.argumentString;
        if (arg)
            [ps insertObject:arg atIndex:0];
        evaluator = evaluator.parent;
    }
    return ps;
}


// Returns the context yank register if any
- (NSString*)yankRegister
{
    // Never use self.yankRegister here. It causes INFINITE LOOP
    if (nil != _yankRegister) {
        return _yankRegister;
    }
    if (nil == self.parent) {
        return _yankRegister;
    }
    else {
        return [self.parent yankRegister];
    }
}

- (void)setYankRegister:(NSString*)yankRegister { _yankRegister = yankRegister; }

- (void)resetNumericArg
{
    _numericArg = 1;
    if (self.parent != nil) {
        [self.parent resetNumericArg];
    }
}

// Returns the context numeric arguments multiplied together
- (NSUInteger)numericArg
{
    // FIXME: This may lead integer overflow.
    // Just cut it to INT_MAX is fine for here I think.
    if (nil == self.parent) {
        return _numericArg;
    }
    else {
        return [self.parent numericArg] * _numericArg;
    }
}

- (void)setNumericArg:(NSUInteger)numericArg { _numericArg = numericArg; }

- (void)textView:(id)view didYank:(NSString*)yankedText withType:(XVIM_TEXT_TYPE)type
{
    [XVIM.registerManager yank:yankedText withType:type onRegister:self.yankRegister];
}

- (void)textView:(id)view didDelete:(NSString*)deletedText withType:(XVIM_TEXT_TYPE)type
{
    [XVIM.registerManager delete:deletedText withType:type onRegister:self.yankRegister];
}

- (XVimCommandLineEvaluator*)searchEvaluatorForward:(BOOL)forward
{
    return [[XVimCommandLineEvaluator alloc] initWithWindow:self.window
                firstLetter:forward ? @"/" : @"?"
                history:[[XVim instance] searchHistory]
                completion:^XVimEvaluator*(NSString* command, XVimMotion** result) {
                    if (command.length == 0) {
                        return nil;
                    }
                    XVim.instance.foundRangesHidden = NO;
                    let view = [self.window sourceView];
                    view.needsUpdateFoundRanges = YES;

                    let forward2 = [command characterAtIndex:0] == '/';
                    if (command.length == 1) {
                        // Repeat search
                        let m = [XVim.instance.searcher motionForRepeatSearch];
                        m.motion = forward2 ? MOTION_SEARCH_FORWARD : MOTION_SEARCH_BACKWARD;
                        m.count = self.numericArg;
                        *result = m;
                    }
                    else {
                        XVim.instance.searcher.lastSearchString = [command substringFromIndex:1];
                        let m = [XVim.instance.searcher motionForSearch:[command substringFromIndex:1]
                                                                        forward:forward2];
                        m.count = self.numericArg;
                        *result = m;
                    }
                    return nil;
                }
                onKeyPress:^void(NSString* command) {
                    if (command.length < 2) {
                        return;
                    }

                    let forward2 = [command characterAtIndex:0] == '/';
                    let m = [XVim.instance.searcher motionForSearch:[command substringFromIndex:1] forward:forward2];
                    if ([command characterAtIndex:0] == '/') {
                        [self.sourceView xvim_highlightNextSearchCandidateForward:m.regex
                                                                            count:self.numericArg
                                                                           option:m.option];
                    }
                    else {
                        [self.sourceView xvim_highlightNextSearchCandidateBackward:m.regex
                                                                             count:self.numericArg
                                                                            option:m.option];
                    }
                }];
}

- (void)beginUndoGrouping
{
    self.beganUndoGrouping = YES;
    [self.sourceView xvim_beginUndoGrouping];
}

- (void)endUndoGrouping
{
    if (self.beganUndoGrouping) {
        [self.sourceView xvim_endUndoGrouping];
        self.beganUndoGrouping = NO;
    }
}

@end
