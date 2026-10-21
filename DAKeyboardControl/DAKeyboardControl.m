//
//  DAKeyboardControl.m
//  Original implementation by Daniel Amitay, Copyright (c) 2012.
//  Modern UIKit keyboard tracking and dismissal for TiDAKeyboardControl.
//

#import "DAKeyboardControl.h"
#import <objc/runtime.h>

static char DAControlKey;
static char DATriggerOffsetKey;
static char DAScrollToBottomThresholdKey;
static char DADismissalCorrectionKey;
@class DAKeyboardController;

// The run loop retains its display link. This target must not retain the
// controller, so releasing the host view can also release the controller.
@interface DADisplayLinkTarget : NSObject
@property (nonatomic, weak) DAKeyboardController *controller;
- (void)tick:(CADisplayLink *)link;
@end

@interface DADismissalScrollView : UIScrollView <UIGestureRecognizerDelegate>
@property (nonatomic, weak) DAKeyboardController *controller;
@end

@interface DAKeyboardController : NSObject
@property (nonatomic, weak) UIView *host;
@property (nonatomic, strong) DADismissalScrollView *dismissalScroll;
@property (nonatomic, weak) UIScrollView *nativeScroll;
@property (nonatomic) UIScrollViewKeyboardDismissMode originalDismissMode;
@property (nonatomic, strong) UIView *trackingView;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *constraints;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, copy) DAKeyboardDidMoveBlock frameHandler;
@property (nonatomic, copy) DAKeyboardDidMoveBlock constraintHandler;
@property (nonatomic, copy) DAKeyboardTouchFilterBlock touchFilter;
@property (nonatomic) CGRect lastFrame;
@property (nonatomic) BOOL originalUsesBottomSafeArea;
@property (nonatomic) CGFloat originalDismissPadding;
@property (nonatomic) BOOL installed;
@property (nonatomic) BOOL tracking;
@property (nonatomic) BOOL opening;
@property (nonatomic) BOOL closing;
@property (nonatomic) BOOL keyboardDismissed;
@property (nonatomic, weak) UIScrollView *scrollingView;
@property (nonatomic) CGFloat originalContentBottom;
@property (nonatomic) CGFloat originalIndicatorBottom;
@property (nonatomic) BOOL hasScrollSnapshot;
@property (nonatomic) BOOL pinnedToBottom;
@property (nonatomic) BOOL pendingOpeningBottomAnchor;
@property (nonatomic) BOOL dismissalTouchCaptured;
@property (nonatomic) BOOL dismissalBottomEligible;
@property (nonatomic) BOOL dismissalMovedKeyboard;
@property (nonatomic) BOOL dismissalPanFinished;
@property (nonatomic) CGFloat dismissalStartKeyboardTop;
@property (nonatomic) BOOL animatingDismissalCorrection;
@property (nonatomic) CGFloat dismissalAnimationTarget;
@property (nonatomic) CFTimeInterval dismissalAnimationDeadline;
@property (nonatomic) CGFloat previousOffset;
@property (nonatomic) CGSize previousContentSize;
@property (nonatomic) CGSize previousViewportSize;
- (void)installWithPanning:(BOOL)panning;
- (void)remove;
- (void)tick;
- (void)hostAttachmentChanged;
- (void)updateTriggerOffset;
- (void)syncDismissalScrollGeometry;
- (BOOL)ownsFirstResponder;
- (void)captureDismissalTouch:(UIView *)view;
- (void)observeDismissalFrame:(CGRect)frame panState:(UIGestureRecognizerState)state;
@end

static UIView *DAFindFirstResponder(UIView *view)
{
    // Titanium's root view can be first responder solely to capture gestures.
    // Only an actual text input establishes keyboard ownership.
    if (view.isFirstResponder && ([view isKindOfClass:UITextField.class] || [view isKindOfClass:UITextView.class])) return view;
    for (UIView *child in view.subviews) {
        UIView *responder = DAFindFirstResponder(child);
        if (responder) return responder;
    }
    return nil;
}

@implementation DADisplayLinkTarget
- (void)tick:(CADisplayLink *)link { [self.controller tick]; }
@end

@implementation DADismissalScrollView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // Titanium can reorder non-proxy subviews during layout. The helper must
    // never intercept taps even if moved above the application's controls.
    // Its pan recognizer is attached to the host and receives those touches.
    return nil;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self.controller hostAttachmentChanged];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
    if (gesture == self.panGestureRecognizer) {
        if (![self.controller ownsFirstResponder]) return NO;
        CGPoint velocity = [self.panGestureRecognizer velocityInView:self.controller.host];
        if (fabs(velocity.x) > fabs(velocity.y)) return NO;
        [self.controller syncDismissalScrollGeometry];
    }
    return [super gestureRecognizerShouldBegin:gesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch
{
    // Decide from the original touched view, before either pan begins. A drag
    // rejected here stays with the TextArea even if the finger leaves it.
    if (gesture == self.panGestureRecognizer) {
        BOOL allowed = !self.controller.touchFilter || self.controller.touchFilter(touch.view);
        [self.controller captureDismissalTouch:allowed ? touch.view : nil];
        if (!allowed) return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    // Preserve table/text-area scrolling. UIKit remains the delegate of its
    // own recognizer; this helper is a UIScrollView subclass, not a replacement.
    return gesture == self.panGestureRecognizer
        && [other.view isKindOfClass:UIScrollView.class]
        && [other.view isDescendantOfView:self.controller.host];
}
@end

@implementation DAKeyboardController
- (void)resetDismissalCorrection
{
    if (self.animatingDismissalCorrection) {
        [self.scrollingView setContentOffset:self.scrollingView.contentOffset animated:NO];
        self.animatingDismissalCorrection = NO;
        self.pinnedToBottom = NO;
        self.previousOffset = self.scrollingView.contentOffset.y;
    }
    self.dismissalTouchCaptured = NO;
    self.dismissalBottomEligible = NO;
    self.dismissalMovedKeyboard = NO;
    self.dismissalPanFinished = NO;
}

- (void)captureDismissalTouch:(UIView *)view
{
    [self captureDismissalTouch:view keyboardFrame:self.tracking ? [self currentFrame] : CGRectZero];
}

- (void)captureDismissalTouch:(UIView *)view keyboardFrame:(CGRect)frame
{
    [self resetDismissalCorrection];
    self.dismissalTouchCaptured = YES;
    UIScrollView *scroll = self.scrollingView;
    if (!self.host.keyboardDismissalScrollCorrection || !scroll.window) return;
    if (!view || (view != scroll && ![view isDescendantOfView:scroll])) return;
    if (frame.size.height < 0.5) return;
    UIEdgeInsets adjusted = scroll.adjustedContentInset;
    CGFloat maximum = MAX(-adjusted.top, scroll.contentSize.height - scroll.bounds.size.height + adjusted.bottom);
    // Record before the table recognizer scrolls the lead-in above the composer.
    self.dismissalBottomEligible = fabs(scroll.contentOffset.y - maximum) <= 12;
    self.dismissalStartKeyboardTop = frame.origin.y;
}

- (void)observeDismissalFrame:(CGRect)frame panState:(UIGestureRecognizerState)state
{
    if (!self.dismissalBottomEligible) return;
    if ((state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
        && frame.origin.y > self.dismissalStartKeyboardTop + 1) self.dismissalMovedKeyboard = YES;
}

- (void)dismissalPanChanged:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan && !self.dismissalTouchCaptured) {
        // A native UIScrollView host keeps UIKit's gesture delegate.
        [self captureDismissalTouch:self.scrollingView];
    }
    [self observeDismissalFrame:[self currentFrame] panState:pan.state];
    if (pan.state == UIGestureRecognizerStateEnded) {
        self.dismissalPanFinished = YES;
        if (!self.dismissalBottomEligible || !self.dismissalMovedKeyboard) [self resetDismissalCorrection];
    }
    else if (pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) [self resetDismissalCorrection];
}

- (void)restoreScrollingView
{
    UIScrollView *scroll = self.scrollingView;
    if (scroll) {
        UIEdgeInsets content = scroll.contentInset;
        content.bottom = self.originalContentBottom;
        UIEdgeInsets indicator = scroll.verticalScrollIndicatorInsets;
        indicator.bottom = self.originalIndicatorBottom;
        [UIView performWithoutAnimation:^{
            scroll.contentInset = content;
            scroll.verticalScrollIndicatorInsets = indicator;
        }];
    }
    [self resetDismissalCorrection];
    self.scrollingView = nil;
    self.hasScrollSnapshot = NO;
    self.pendingOpeningBottomAnchor = NO;
    [self syncDismissalScrollGeometry];
}

- (void)captureKeyboardOpeningAnchor
{
    // Capture using the pre-opening viewport/insets. Repeated will-show events
    // (for example input changes while already open) must not reclassify history.
    UIScrollView *scroll = self.scrollingView;
    CGFloat threshold = self.host.keyboardScrollToBottomThreshold;
    self.pendingOpeningBottomAnchor = NO;
    if (!scroll.window || threshold <= 0 || scroll.tracking || scroll.dragging || scroll.decelerating) return;
    UIEdgeInsets adjusted = scroll.adjustedContentInset;
    CGFloat maximum = MAX(-adjusted.top, scroll.contentSize.height - scroll.bounds.size.height + adjusted.bottom);
    self.pendingOpeningBottomAnchor = fabs(maximum - scroll.contentOffset.y) <= threshold;
}

- (void)updateScrollingView:(UIScrollView *)scroll occludedHeight:(CGFloat)height
{
    if (scroll != self.scrollingView) {
        [self restoreScrollingView];
        self.scrollingView = scroll;
        self.originalContentBottom = scroll.contentInset.bottom;
        self.originalIndicatorBottom = scroll.verticalScrollIndicatorInsets.bottom;
    }
    if (!scroll || !scroll.window) return;

    UIEdgeInsets adjusted = scroll.adjustedContentInset;
    CGFloat minimum = -adjusted.top;
    CGFloat maximum = MAX(minimum, scroll.contentSize.height - scroll.bounds.size.height + adjusted.bottom);
    CGFloat offset = scroll.contentOffset.y;
    BOOL interacting = scroll.tracking || scroll.dragging || scroll.decelerating;
    BOOL sizeChanged = !CGSizeEqualToSize(self.previousContentSize, scroll.contentSize)
        || !CGSizeEqualToSize(self.previousViewportSize, scroll.bounds.size);
    if (self.animatingDismissalCorrection && (interacting
        || fabs(offset - self.dismissalAnimationTarget) < 0.1
        || CACurrentMediaTime() > self.dismissalAnimationDeadline)) {
        self.animatingDismissalCorrection = NO;
        self.pinnedToBottom = fabs(offset - maximum) <= 12;
    }
    if (self.animatingDismissalCorrection) {
        // UIKit owns this offset animation. Display-link inset updates must
        // not replace intermediate animation offsets with a nonanimated jump.
    } else if (!self.hasScrollSnapshot) {
        self.pinnedToBottom = fabs(offset - maximum) <= 12;
    } else if (interacting || (!sizeChanged && fabs(offset - self.previousOffset) > 0.5)) {
        // Only user/application scrolling changes the anchor. Content growth
        // and our own inset updates must not turn a bottom reader into history.
        self.pinnedToBottom = fabs(offset - maximum) <= 12;
    }

    if (!self.host.keyboardDismissalScrollCorrection) [self resetDismissalCorrection];
    BOOL keyboardSettling = self.tracking && fabs([self currentFrame].origin.y
        - CGRectGetMinY(self.host.keyboardLayoutGuide.layoutFrame)) > 0.5;
    BOOL animateCorrection = NO;
    if (self.dismissalBottomEligible && self.dismissalMovedKeyboard && self.dismissalPanFinished
        && !interacting && !keyboardSettling && !self.opening && !self.closing) {
        self.pinnedToBottom = YES;
        animateCorrection = !UIAccessibilityIsReduceMotionEnabled();
        [self resetDismissalCorrection];
    }

    if (self.pendingOpeningBottomAnchor) {
        if (!interacting) self.pinnedToBottom = YES;
        self.pendingOpeningBottomAnchor = NO;
    }

    // UIKit may already contribute the home-indicator safe area. Add only the
    // extra obstruction, preserving the app's original bottom content padding.
    CGFloat systemBottom = MAX(0, adjusted.bottom - scroll.contentInset.bottom);
    CGFloat extra = MAX(0, height - systemBottom);
    UIEdgeInsets content = scroll.contentInset;
    content.bottom = self.originalContentBottom + extra;
    UIEdgeInsets indicator = scroll.verticalScrollIndicatorInsets;
    indicator.bottom = self.originalIndicatorBottom + extra;
    BOOL insetChanged = fabs(content.bottom - scroll.contentInset.bottom) > 0.1;
    __block CGFloat animatedTarget = self.dismissalAnimationTarget;
    [UIView performWithoutAnimation:^{
        if (insetChanged) scroll.contentInset = content;
        if (!UIEdgeInsetsEqualToEdgeInsets(indicator, scroll.verticalScrollIndicatorInsets)) scroll.verticalScrollIndicatorInsets = indicator;
        UIEdgeInsets updated = scroll.adjustedContentInset;
        CGFloat newMinimum = -updated.top;
        CGFloat newMaximum = MAX(newMinimum, scroll.contentSize.height - scroll.bounds.size.height + updated.bottom);
        CGFloat target = self.pinnedToBottom && !interacting ? newMaximum : MIN(newMaximum, MAX(newMinimum, offset));
        if (animateCorrection || self.animatingDismissalCorrection) {
            animatedTarget = newMaximum;
        } else if ((insetChanged || sizeChanged || (self.pinnedToBottom && !interacting)) && fabs(scroll.contentOffset.y - target) > 0.1) {
            [scroll setContentOffset:CGPointMake(scroll.contentOffset.x, target) animated:NO];
        }
    }];
    if (animateCorrection || (self.animatingDismissalCorrection && fabs(animatedTarget - self.dismissalAnimationTarget) > 0.1)) {
        self.animatingDismissalCorrection = YES;
        self.dismissalAnimationTarget = animatedTarget;
        self.dismissalAnimationDeadline = CACurrentMediaTime() + 1;
        // Keep outside performWithoutAnimation; UIKit handles interruption by a drag.
        [scroll setContentOffset:CGPointMake(scroll.contentOffset.x, animatedTarget) animated:YES];
    }
    self.previousOffset = scroll.contentOffset.y;
    self.previousContentSize = scroll.contentSize;
    self.previousViewportSize = scroll.bounds.size;
    self.hasScrollSnapshot = YES;
    [self syncDismissalScrollGeometry];
}

- (void)installWithPanning:(BOOL)panning
{
    UIView *host = self.host;
    self.installed = YES;
    self.lastFrame = CGRectNull;
    UIKeyboardLayoutGuide *guide = host.keyboardLayoutGuide;
    self.originalUsesBottomSafeArea = guide.usesBottomSafeArea;
    self.originalDismissPadding = guide.keyboardDismissPadding;
    // A dismissed keyboard produces zero translation. Titanium owns the
    // safe-area layout of each locked view; the bridge accounts for its parent.
    guide.usesBottomSafeArea = NO;
    [self updateTriggerOffset];

    if (panning && [host isKindOfClass:UIScrollView.class]) {
        self.nativeScroll = (UIScrollView *)host;
        self.originalDismissMode = self.nativeScroll.keyboardDismissMode;
        self.nativeScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    } else {
        // Native dismissal also works for a plain UIView by attaching the
        // helper's public pan recognizer to it. No Titanium children are moved.
        DADismissalScrollView *scroll = [[DADismissalScrollView alloc] initWithFrame:host.bounds];
        scroll.controller = self;
        scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        scroll.contentSize = host.bounds.size;
        scroll.alwaysBounceVertical = YES;
        scroll.showsVerticalScrollIndicator = NO;
        scroll.showsHorizontalScrollIndicator = NO;
        scroll.accessibilityElementsHidden = YES;
        scroll.scrollsToTop = NO;
        // This empty helper is not application content. On iOS 26+, UIKit
        // gives scroll views automatic effects beneath system bars; allowing
        // this helper to draw them can shade a stationary navigation bar.
        if (@available(iOS 26.0, *)) {
            scroll.topEdgeEffect.hidden = YES;
            scroll.bottomEdgeEffect.hidden = YES;
            scroll.leftEdgeEffect.hidden = YES;
            scroll.rightEdgeEffect.hidden = YES;
        }
        scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        self.dismissalScroll = scroll;
        [host insertSubview:scroll atIndex:0];
        if (panning) {
            scroll.panGestureRecognizer.cancelsTouchesInView = NO;
            [host addGestureRecognizer:scroll.panGestureRecognizer];
        } else {
            scroll.userInteractionEnabled = NO;
        }
    }

    if (panning) {
        UIPanGestureRecognizer *pan = self.nativeScroll ? self.nativeScroll.panGestureRecognizer : self.dismissalScroll.panGestureRecognizer;
        [pan addTarget:self action:@selector(dismissalPanChanged:)];
    }

    // Sample this app-owned view's presentation frame for animated show/hide
    // and interactive movement. The guide's model frame jumps to the animation
    // destination during an ordinary keyboard presentation or dismissal.
    UIView *tracker = [[UIView alloc] init];
    tracker.translatesAutoresizingMaskIntoConstraints = NO;
    tracker.userInteractionEnabled = NO;
    tracker.accessibilityElementsHidden = YES;
    self.trackingView = tracker;
    [host insertSubview:tracker atIndex:0];
    self.constraints = @[
        [tracker.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [tracker.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
        [tracker.widthAnchor constraintEqualToAnchor:host.widthAnchor],
        [tracker.heightAnchor constraintEqualToConstant:1]
    ];
    [NSLayoutConstraint activateConstraints:self.constraints];

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(inputBegan:) name:UITextFieldTextDidBeginEditingNotification object:nil];
    [center addObserver:self selector:@selector(inputBegan:) name:UITextViewTextDidBeginEditingNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [center addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [self hostAttachmentChanged];
}

- (void)syncDismissalScrollGeometry
{
    UIScrollView *helper = self.dismissalScroll;
    if (!helper || helper.panGestureRecognizer.view != self.host) return;
    UIScrollView *scroll = self.scrollingView;
    CGFloat range = 0, distanceFromTop = 0;
    if (scroll && scroll.window) {
        UIEdgeInsets insets = scroll.adjustedContentInset;
        range = MAX(0, scroll.contentSize.height + insets.top + insets.bottom - scroll.bounds.size.height);
        distanceFromTop = MIN(range, MAX(0, scroll.contentOffset.y + insets.top));
    }
    CGSize size = CGSizeMake(self.host.bounds.size.width, self.host.bounds.size.height + range);
    // UIKit can consider this helper when coordinating sheet/scroll gestures.
    // Advertise the real table's scrollable range and distance from its top,
    // rather than an empty scroll view that is always at the sheet handoff edge.
    [UIView performWithoutAnimation:^{
        if (!CGSizeEqualToSize(helper.contentSize, size)) helper.contentSize = size;
        if (fabs(helper.contentOffset.y - distanceFromTop) > 0.1)
            helper.contentOffset = CGPointMake(0, distanceFromTop);
    }];
}

- (void)updateTriggerOffset
{
    if (self.installed) {
        self.host.keyboardLayoutGuide.keyboardDismissPadding = MAX(0, self.host.keyboardTriggerOffset);
    }
}

- (BOOL)ownsFirstResponder
{
    return self.host.window != nil && DAFindFirstResponder(self.host) != nil;
}

- (void)startDisplayLink
{
    if (self.displayLink || !self.installed || !self.host.window) return;
    DADisplayLinkTarget *target = [[DADisplayLinkTarget alloc] init];
    target.controller = self;
    self.displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)hostAttachmentChanged
{
    if (!self.installed) return;
    if (!self.host.window) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        self.tracking = NO;
        return;
    }
    self.tracking = !self.keyboardDismissed && [self ownsFirstResponder];
    [self startDisplayLink];
}

- (void)inputBegan:(NSNotification *)notification
{
    UIView *input = notification.object;
    if ([input isKindOfClass:UIView.class] && [input isDescendantOfView:self.host]) {
        // A cancelled navigation transition can restore editing while leaving
        // the software keyboard hidden. Focus alone must not rearm tracking.
        [self startDisplayLink];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    if (![self ownsFirstResponder]) return;
    if (!self.tracking || self.keyboardDismissed) [self captureKeyboardOpeningAnchor];
    self.keyboardDismissed = NO;
    self.tracking = YES;
    self.opening = YES;
    self.closing = NO;
    [self startDisplayLink];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if (!self.tracking) return;
    self.opening = NO;
    self.closing = YES;
    [self startDisplayLink];
}

- (void)keyboardDidHide:(NSNotification *)notification
{
    // Once UIKit confirms dismissal, ignore presentation-layer movement from
    // navigation rollback until a genuine keyboard presentation begins.
    self.keyboardDismissed = YES;
    self.tracking = NO;
    self.opening = NO;
    self.closing = NO;
    [self tick];
}

- (CGRect)currentFrame
{
    UIView *host = self.host;
    CGRect bounds = host.bounds;
    CGFloat bottom = CGRectGetMaxY(bounds);
    UIPanGestureRecognizer *pan = self.nativeScroll ? self.nativeScroll.panGestureRecognizer : self.dismissalScroll.panGestureRecognizer;
    BOOL interactive = pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged;
    if (interactive) [host layoutIfNeeded];
    CGFloat top = CGRectGetMinY(host.keyboardLayoutGuide.layoutFrame);
    CALayer *presentation = self.trackingView.layer.presentationLayer;
    // During a drag the guide already contains the current touch-driven
    // position. Its presentation layer describes the previous rendered frame.
    // Use presentation sampling only for the keyboard's settling animations.
    if (!interactive && presentation) {
        CALayer *hostPresentation = host.layer.presentationLayer;
        CGFloat visibleBottom = hostPresentation ? CGRectGetMaxY(hostPresentation.bounds) : bottom;
        // The sheet can animate the host's height while the keyboard animates
        // the guide. Measure overlap in the same rendered coordinate space,
        // then express it against model bounds for Titanium's locked views.
        // Mixing the final host bottom with an intermediate guide top creates
        // a phantom keyboard overlap as a medium sheet expands to large.
        CGFloat visibleOverlap = MAX(0, visibleBottom - CGRectGetMinY(presentation.frame));
        top = bottom - visibleOverlap;
    }
    top = MIN(bottom, MAX(CGRectGetMinY(bounds), top));
    return CGRectMake(CGRectGetMinX(bounds), top, CGRectGetWidth(bounds), bottom - top);
}

- (void)tick
{
    UIView *host = self.host;
    if (!self.installed || !host.window) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        return;
    }
    [self syncDismissalScrollGeometry];
    CGRect frame = self.tracking ? [self currentFrame]
        : CGRectMake(CGRectGetMinX(host.bounds), CGRectGetMaxY(host.bounds), CGRectGetWidth(host.bounds), 0);
    UIPanGestureRecognizer *pan = self.nativeScroll ? self.nativeScroll.panGestureRecognizer : self.dismissalScroll.panGestureRecognizer;
    [self observeDismissalFrame:frame panState:pan.state];
    // Apply every frame so a parent bounds/safe-area change updates locked
    // views even if the keyboard is stationary. The bridge suppresses repeated
    // JS events and unchanged native transforms independently.
    if (self.constraintHandler) self.constraintHandler(frame, self.opening, self.closing);
    if (self.frameHandler) self.frameHandler(frame, self.opening, self.closing);
    self.lastFrame = frame;
    if (fabs(frame.origin.y - CGRectGetMinY(host.keyboardLayoutGuide.layoutFrame)) < 0.5) {
        self.opening = NO;
        self.closing = NO;
    }
    if (frame.size.height < 0.5 && (self.keyboardDismissed || ![self ownsFirstResponder])) {
        self.tracking = NO;
        self.opening = NO;
        self.closing = NO;
        // An opted-in table also needs composer resize/content-size updates
        // while the keyboard is hidden. Poll only while the host is attached.
        if (!self.scrollingView) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
    }
}

- (void)remove
{
    if (!self.installed) return;
    self.installed = NO;
    UIPanGestureRecognizer *pan = self.nativeScroll ? self.nativeScroll.panGestureRecognizer : self.dismissalScroll.panGestureRecognizer;
    [pan removeTarget:self action:@selector(dismissalPanChanged:)];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.frameHandler = nil;
    self.constraintHandler = nil;
    self.touchFilter = nil;
    [self restoreScrollingView];
    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [self.trackingView removeFromSuperview];
    if (self.dismissalScroll) {
        [self.host removeGestureRecognizer:self.dismissalScroll.panGestureRecognizer];
        self.dismissalScroll.controller = nil;
        [self.dismissalScroll removeFromSuperview];
    }
    self.nativeScroll.keyboardDismissMode = self.originalDismissMode;
    self.host.keyboardLayoutGuide.usesBottomSafeArea = self.originalUsesBottomSafeArea;
    self.host.keyboardLayoutGuide.keyboardDismissPadding = self.originalDismissPadding;
    self.constraints = nil;
    self.trackingView = nil;
    self.dismissalScroll = nil;
    self.nativeScroll = nil;
}

- (void)dealloc { [self remove]; }
@end

@implementation UIView (DAKeyboardControl)
- (void)updateKeyboardScrollingView:(UIScrollView *)scrollView occludedHeight:(CGFloat)height
{
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    [controller updateScrollingView:scrollView occludedHeight:height];
}

- (void)refreshKeyboardControl
{
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    [controller startDisplayLink];
}

- (void)addKeyboardControl:(BOOL)panning frameHandler:(DAKeyboardDidMoveBlock)frameHandler constraintHandler:(DAKeyboardDidMoveBlock)constraintHandler
{
    [self removeKeyboardControl];
    DAKeyboardController *controller = [[DAKeyboardController alloc] init];
    controller.host = self;
    controller.frameHandler = frameHandler;
    controller.constraintHandler = constraintHandler;
    objc_setAssociatedObject(self, &DAControlKey, controller, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [controller installWithPanning:panning];
}

- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)handler
{
    [self addKeyboardControl:YES frameHandler:handler constraintHandler:nil];
}
- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)handler shouldReceiveTouch:(DAKeyboardTouchFilterBlock)touchFilter
{
    [self addKeyboardPanningWithActionHandler:handler];
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    controller.touchFilter = touchFilter;
}
- (void)addKeyboardPanningWithFrameBasedActionHandler:(DAKeyboardDidMoveBlock)frameHandler constraintBasedActionHandler:(DAKeyboardDidMoveBlock)constraintHandler
{
    [self addKeyboardControl:YES frameHandler:frameHandler constraintHandler:constraintHandler];
}
- (void)addKeyboardNonpanningWithActionHandler:(DAKeyboardDidMoveBlock)handler
{
    [self addKeyboardControl:NO frameHandler:handler constraintHandler:nil];
}
- (void)addKeyboardNonpanningWithFrameBasedActionHandler:(DAKeyboardDidMoveBlock)frameHandler constraintBasedActionHandler:(DAKeyboardDidMoveBlock)constraintHandler
{
    [self addKeyboardControl:NO frameHandler:frameHandler constraintHandler:constraintHandler];
}
- (void)removeKeyboardControl
{
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    [controller remove];
    objc_setAssociatedObject(self, &DAControlKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)keyboardDismissalScrollCorrection
{
    NSNumber *value = objc_getAssociatedObject(self, &DADismissalCorrectionKey);
    return value ? value.boolValue : YES;
}
- (void)setKeyboardDismissalScrollCorrection:(BOOL)enabled
{
    objc_setAssociatedObject(self, &DADismissalCorrectionKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!enabled) {
        DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
        [controller resetDismissalCorrection];
    }
}
- (CGFloat)keyboardScrollToBottomThreshold
{
    NSNumber *value = objc_getAssociatedObject(self, &DAScrollToBottomThresholdKey);
    return value ? value.doubleValue : 60;
}
- (void)setKeyboardScrollToBottomThreshold:(CGFloat)threshold
{
    objc_setAssociatedObject(self, &DAScrollToBottomThresholdKey, @(isfinite(threshold) ? MAX(0, threshold) : 60), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (CGFloat)keyboardTriggerOffset
{
    return [objc_getAssociatedObject(self, &DATriggerOffsetKey) doubleValue];
}
- (void)setKeyboardTriggerOffset:(CGFloat)offset
{
    objc_setAssociatedObject(self, &DATriggerOffsetKey, @(MAX(0, offset)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    [controller updateTriggerOffset];
}
- (CGRect)keyboardFrameInView
{
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    if (controller && !CGRectIsNull(controller.lastFrame)) return controller.lastFrame;
    return CGRectMake(CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds), CGRectGetWidth(self.bounds), 0);
}
- (BOOL)isKeyboardOpened { return self.keyboardFrameInView.size.height > 0.5; }
- (BOOL)keyboardWillRecede
{
    DAKeyboardController *controller = objc_getAssociatedObject(self, &DAControlKey);
    UIPanGestureRecognizer *pan = controller.nativeScroll ? controller.nativeScroll.panGestureRecognizer : controller.dismissalScroll.panGestureRecognizer;
    return pan && pan.state == UIGestureRecognizerStateChanged && [pan velocityInView:self].y > 0;
}
- (void)hideKeyboard { [self endEditing:YES]; }
@end
