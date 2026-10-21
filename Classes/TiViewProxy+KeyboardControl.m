/**
 * Copyright (c) 2014 SMC Treviso s.r.l. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 2.1 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */


#import "TiBase.h"
#import "TiComplexValue.h"
#import "Ti2DMatrix.h"
#import "TiViewProxy.h"
#import "TiViewProxy+KeyboardControl.h"
#import "DAKeyboardControl.h"
// Resolve the optional TableView at runtime so panning-only consumers do not
// acquire a native link dependency on Titanium's TableView feature.
@protocol DAKCTableViewAccess <NSObject>
- (UITableView *)tableView;
@end


@implementation TiViewProxy (KeyboardControl)


DEFINE_DEF_PROP(lockedViews, nil);

- (id)keyboardDismissalScrollCorrection
{
    return [self valueForUndefinedKey:@"keyboardDismissalScrollCorrection"] ?: @YES;
}
- (void)setKeyboardDismissalScrollCorrection:(id)value
{
    ENSURE_UI_THREAD(setKeyboardDismissalScrollCorrection, value);
    ENSURE_TYPE(value, NSNumber);
    [self replaceValue:@([value boolValue]) forKey:@"keyboardDismissalScrollCorrection" notification:NO];
    if ([self viewInitialized]) self.view.keyboardDismissalScrollCorrection = [value boolValue];
}

- (id)keyboardScrollToBottomThreshold
{
    return [self valueForUndefinedKey:@"keyboardScrollToBottomThreshold"] ?: @60;
}

- (void)setKeyboardScrollToBottomThreshold:(id)value
{
    ENSURE_UI_THREAD(setKeyboardScrollToBottomThreshold, value);
    ENSURE_TYPE(value, NSNumber);
    double threshold = [value doubleValue];
    if (!isfinite(threshold) || threshold < 0) {
        [NSException raise:NSInvalidArgumentException format:@"keyboardScrollToBottomThreshold requires a finite nonnegative number"];
    }
    [self replaceValue:value forKey:@"keyboardScrollToBottomThreshold" notification:NO];
    if ([self viewInitialized]) self.view.keyboardScrollToBottomThreshold = threshold;
}

- (id)keyboardScrollingView
{
    return [self valueForUndefinedKey:@"keyboardScrollingView"];
}

- (void)setKeyboardScrollingView:(id)value
{
    ENSURE_UI_THREAD(setKeyboardScrollingView, value);
    if (value == [NSNull null]) value = nil;
    ENSURE_TYPE_OR_NIL(value, TiViewProxy);
    if (value && ![value isKindOfClass:NSClassFromString(@"TiUITableViewProxy")]) {
        [NSException raise:NSInvalidArgumentException format:@"keyboardScrollingView requires a Ti.UI.TableView or null"];
    }
    [self replaceValue:value ?: [NSNull null] forKey:@"keyboardScrollingView" notification:NO];
    if ([self viewInitialized]) [self.view refreshKeyboardControl];
}

- (void)updateKeyboardPanningScrollingView:(CGRect)keyboardFrame
{
    id proxy = [self keyboardScrollingView];
    UIScrollView *scroll = nil;
    if ([proxy isKindOfClass:TiViewProxy.class] && [proxy viewInitialized]) {
        UIView *native = [proxy view];
        if ([native isKindOfClass:NSClassFromString(@"TiUITableView")] && [native isDescendantOfView:self.view]) {
            scroll = [(id<DAKCTableViewAccess>)native tableView];
        }
    }
    CGFloat occlusion = 0;
    if (scroll && scroll.window) {
        CGRect viewport = [scroll convertRect:scroll.bounds toView:self.view];
        CGFloat coveredTop = keyboardFrame.size.height > 0 ? keyboardFrame.origin.y : CGRectGetMaxY(viewport);
        for (id locked in [self lockedViews]) {
            if (![locked isKindOfClass:TiViewProxy.class] || ![locked viewInitialized]) continue;
            UIView *view = [locked view];
            if (view.hidden || view.alpha < 0.01 || ![view isDescendantOfView:self.view]) continue;
            CGRect frame = [view convertRect:view.bounds toView:self.view];
            if (CGRectIntersectsRect(frame, viewport)) coveredTop = MIN(coveredTop, CGRectGetMinY(frame));
        }
        occlusion = MAX(0, CGRectGetMaxY(viewport) - MAX(CGRectGetMinY(viewport), coveredTop));
    }
    [self.view updateKeyboardScrollingView:scroll occludedHeight:occlusion];
}


- (void)setKeyboardPanning:(id)args
{
    ENSURE_UI_THREAD(setKeyboardPanning, args);

    BOOL oldValue = [TiUtils boolValue:[self keyboardPanning] def:NO];
    BOOL newValue = [TiUtils boolValue:args def:NO];

    [self replaceValue:[NSNumber numberWithBool:newValue]
                forKey:@"keyboardPanning"
          notification:NO];

    if (newValue && !oldValue)
    {
        // Constructor properties are applied before Titanium finishes creating
        // the safe-area proxy and native property maps. Defer native view
        // creation until that initialization has completed.
        [self performSelector:@selector(setupKeyboardPanning) withObject:nil afterDelay:0];
    }
    else if (!newValue && oldValue)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setupKeyboardPanning) object:nil];
        [self teardownKeyboardPanning];
    }
}


- (id)keyboardPanning
{
    id value = [self valueForUndefinedKey:@"keyboardPanning"];
    if (value == nil || value == [NSNull null] || ![value respondsToSelector:@selector(boolValue)])
    {
        return @NO;
    }
    else
    {
        return @([value boolValue]);
    }
}


- (void)setupKeyboardPanning
{
    if (![TiUtils boolValue:[self keyboardPanning] def:NO]) return;
    self.view.keyboardDismissalScrollCorrection = [TiUtils boolValue:[self keyboardDismissalScrollCorrection] def:YES];
    self.view.keyboardScrollToBottomThreshold = [TiUtils floatValue:[self keyboardScrollToBottomThreshold] def:60];
    self.view.keyboardTriggerOffset = [TiUtils floatValue:[self valueForUndefinedKey:@"keyboardTriggerOffset"] def:0];
    [self replaceValue:self.view
                forKey:@"keyboardPanningView"
          notification:NO];

    // This bridge is compiled without ARC. A __block reference is non-owning
    // here; retaining self from the view's callback would create a proxy cycle.
    __block TiViewProxy *panningProxy = self;
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        [panningProxy updateKeyboardPanningLockedViews:keyboardFrameInView];
        [panningProxy updateKeyboardPanningScrollingView:keyboardFrameInView];
        [panningProxy fireEventForKeyboardFrameInView:keyboardFrameInView];
    } shouldReceiveTouch:^BOOL(UIView *touchedView) {
        // UIKit may hit a TextArea's internal text/selection view. Walk its
        // ancestors to find the UITextView, then check the current lockedViews.
        UIView *host = panningProxy.view;
        UIView *textArea = touchedView;
        while (textArea && textArea != host && ![textArea isKindOfClass:UITextView.class]) {
            textArea = textArea.superview;
        }
        if (![textArea isKindOfClass:UITextView.class]) return YES;
        id lockedViews = [panningProxy lockedViews];
        if (![lockedViews isKindOfClass:NSArray.class]) return YES;
        for (id proxy in lockedViews) {
            if (![proxy isKindOfClass:TiViewProxy.class] || ![proxy viewInitialized]) continue;
            UIView *lockedView = [proxy view];
            if ([lockedView isDescendantOfView:host] && [textArea isDescendantOfView:lockedView]) {
                return NO;
            }
        }
        return YES;
    }];
}


- (void)teardownKeyboardPanning
{
    id panningView = [self valueForKey:@"keyboardPanningView"];
    if ([panningView isKindOfClass:UIView.class]) {
        [panningView removeKeyboardControl];
        if ([panningView window]) {
            CGRect bounds = [panningView bounds];
            [self updateKeyboardPanningLockedViews:CGRectMake(0, CGRectGetMaxY(bounds), CGRectGetWidth(bounds), 0)];
        }
    }
    [self replaceValue:[NSNull null] forKey:@"keyboardPanningView" notification:NO];
    [self replaceValue:[NSNull null] forKey:@"keyboardPanningLastFrame" notification:NO];
}


- (void)fireEventForKeyboardFrameInView:(CGRect)keyboardFrameInView
{
    if (![self _hasListeners:@"keyboardchange"]) {
        return;
    }

    id previousFrame = [self valueForUndefinedKey:@"keyboardPanningLastFrame"];
    if ([previousFrame isKindOfClass:NSValue.class] && CGRectEqualToRect([previousFrame CGRectValue], keyboardFrameInView)) return;
    [self replaceValue:[NSValue valueWithCGRect:keyboardFrameInView] forKey:@"keyboardPanningLastFrame" notification:NO];

    NSNumber * keyboardWidth = [NSNumber numberWithFloat:keyboardFrameInView.size.width];
    NSNumber * keyboardHeight = [NSNumber numberWithFloat:keyboardFrameInView.size.height];
    NSNumber * keyboardX = [NSNumber numberWithFloat:keyboardFrameInView.origin.x];
    NSNumber * keyboardY = [NSNumber numberWithFloat:keyboardFrameInView.origin.y];

    NSMutableDictionary * event = [NSMutableDictionary dictionary];

    [event setValue:keyboardHeight
             forKey:@"height"];

    [event setValue:keyboardWidth
             forKey:@"width"];

    [event setValue:keyboardX
             forKey:@"x"];

    [event setValue:keyboardY
             forKey:@"y"];

    [self fireEvent:@"keyboardchange" withObject:event];
}


- (void)updateKeyboardPanningLockedViews:(CGRect)keyboardFrameInView
{
    ENSURE_UI_THREAD(updateKeyboardPanningLockedViews, keyboardFrameInView);

    NSArray * lockedViews = [self lockedViews];

    ENSURE_TYPE_OR_NIL(lockedViews, NSArray);

    if (lockedViews == nil || [lockedViews count] == 0)
    {
        return;
    }

    for (TiViewProxy * proxy in lockedViews) {
        if ([proxy isKindOfClass:TiViewProxy.class])
        {
            UIView *nativeView = proxy.view;
            UIView *parentView = nativeView.superview;
            if (!parentView || ![nativeView isDescendantOfView:self.view]) continue;
            // The real parent is already inset by Titanium when extendSafeArea
            // or extendEdges limits the content. Convert it to the host's local
            // coordinates rather than subtracting the home-indicator inset twice.
            CGRect parentBounds = [parentView convertRect:parentView.bounds toView:self.view];
            CGFloat bottom = MIN(CGRectGetMaxY(self.view.bounds), CGRectGetMaxY(parentBounds));
            CGFloat shift = keyboardFrameInView.size.height <= 0 ? 0 : MAX(0, bottom - keyboardFrameInView.origin.y);
            [self updateKeyboardPanningLockedView:proxy with:shift];
        }
    }
}


- (void)updateKeyboardPanningLockedView:(TiViewProxy *)proxy with:(float)shift
{
    TiUIView * proxyView = [proxy view];

    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -shift);

    if (CGAffineTransformEqualToTransform(proxyView.transform, transform)) return;

    Ti2DMatrix * matrix = [[[Ti2DMatrix alloc] initWithMatrix:transform] autorelease];

    // Keep the JS value current, but apply once on the UI thread. A property
    // notification can queue a second update behind the live keyboard motion.
    [proxy replaceValue:matrix forKey:@"transform" notification:NO];
    [UIView performWithoutAnimation:^{ [proxyView setTransform_:matrix]; }];
}


- (void)setKeyboardTriggerOffset:(id)args
{
    ENSURE_UI_THREAD(setKeyboardTriggerOffset, args);
    float offset = MAX(0, [TiUtils floatValue:args def:0.0f]);
    [self replaceValue:@(offset) forKey:@"keyboardTriggerOffset" notification:NO];
    if ([self viewInitialized]) self.view.keyboardTriggerOffset = offset;
}


@end
