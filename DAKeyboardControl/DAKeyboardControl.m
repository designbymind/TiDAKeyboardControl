//
//  DAKeyboardControl.m
//  Original implementation by Daniel Amitay, Copyright (c) 2012.
//  Modern UIKit keyboard tracking and dismissal for TiDAKeyboardControl.
//

#import "DAKeyboardControl.h"
#import <objc/runtime.h>

static char DAControlKey;
static char DATriggerOffsetKey;
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
@property (nonatomic) CGRect lastFrame;
@property (nonatomic) BOOL originalUsesBottomSafeArea;
@property (nonatomic) CGFloat originalDismissPadding;
@property (nonatomic) BOOL installed;
@property (nonatomic) BOOL tracking;
@property (nonatomic) BOOL opening;
@property (nonatomic) BOOL closing;
- (void)installWithPanning:(BOOL)panning;
- (void)remove;
- (void)tick;
- (void)hostAttachmentChanged;
- (void)updateTriggerOffset;
- (BOOL)ownsFirstResponder;
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
    }
    return [super gestureRecognizerShouldBegin:gesture];
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
    [self hostAttachmentChanged];
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
    self.tracking = [self ownsFirstResponder];
    [self startDisplayLink];
}

- (void)inputBegan:(NSNotification *)notification
{
    UIView *input = notification.object;
    if ([input isKindOfClass:UIView.class] && [input isDescendantOfView:self.host]) {
        self.tracking = YES;
        [self startDisplayLink];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    if (![self ownsFirstResponder]) return;
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
    if (!interactive && presentation) top = CGRectGetMinY(presentation.frame);
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
    if (self.dismissalScroll && !CGSizeEqualToSize(self.dismissalScroll.contentSize, host.bounds.size)) {
        self.dismissalScroll.contentSize = host.bounds.size;
    }
    CGRect frame = self.tracking ? [self currentFrame]
        : CGRectMake(CGRectGetMinX(host.bounds), CGRectGetMaxY(host.bounds), CGRectGetWidth(host.bounds), 0);
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
    if (frame.size.height < 0.5 && ![self ownsFirstResponder]) {
        self.tracking = NO;
        self.opening = NO;
        self.closing = NO;
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)remove
{
    if (!self.installed) return;
    self.installed = NO;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.frameHandler = nil;
    self.constraintHandler = nil;
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
