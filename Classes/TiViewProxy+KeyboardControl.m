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


@implementation TiViewProxy (KeyboardControl)


DEFINE_DEF_PROP(lockedViews, nil);


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
    self.view.keyboardTriggerOffset = [TiUtils floatValue:[self valueForUndefinedKey:@"keyboardTriggerOffset"] def:0];
    [self replaceValue:self.view
                forKey:@"keyboardPanningView"
          notification:NO];

    // This bridge is compiled without ARC. A __block reference is non-owning
    // here; retaining self from the view's callback would create a proxy cycle.
    __block TiViewProxy *panningProxy = self;
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        [panningProxy updateKeyboardPanningLockedViews:keyboardFrameInView];
        [panningProxy fireEventForKeyboardFrameInView:keyboardFrameInView];
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
