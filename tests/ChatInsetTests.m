#import <UIKit/UIKit.h>
#import "DAKeyboardControl.h"
#include <stdio.h>
#include <stdlib.h>

@protocol OpeningAnchorTestAccess
- (CGRect)currentFrame;
- (void)tick;
- (void)captureKeyboardOpeningAnchor;
- (void)captureDismissalTouch:(UIView *)view keyboardFrame:(CGRect)frame;
- (void)observeDismissalFrame:(CGRect)frame panState:(UIGestureRecognizerState)state;
- (void)dismissalPanChanged:(UIPanGestureRecognizer *)pan;
@end
static id<OpeningAnchorTestAccess> testController(UIView *host) {
    for (UIView *view in host.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"DADismissalScrollView"]) return [view valueForKey:@"controller"];
    }
    return nil;
}
static int failures;
static void check(BOOL condition, const char *name) {
    printf("%s %s\n", condition ? "PASS" : "FAIL", name);
    if (!condition) failures++;
    fflush(stdout);
}
static BOOL near(CGFloat a, CGFloat b) { return fabs(a - b) < 0.5; }

@interface TestPan : UIPanGestureRecognizer
@property(nonatomic) UIGestureRecognizerState simulatedState;
@end
@implementation TestPan
- (UIGestureRecognizerState)state { return self.simulatedState; }
@end

@interface TestScrollView : UIScrollView
@property(nonatomic) BOOL pretendTracking;
@property(nonatomic) NSUInteger animatedRequests;
@property(nonatomic) BOOL deferAnimatedOffsets;
@property(nonatomic) CGPoint requestedAnimatedOffset;
@end
@implementation TestScrollView
- (BOOL)isTracking { return self.pretendTracking || [super isTracking]; }
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if (animated) {
        self.animatedRequests++;
        self.requestedAnimatedOffset = offset;
        if (self.deferAnimatedOffsets) return;
    }
    // Numeric tests normally complete requested animations synchronously.
    [super setContentOffset:offset animated:NO];
}
@end

@interface TestScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation TestScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{ [self runTests]; });
}
- (void)runTests {
    UIView *host = self.window.rootViewController.view;
    TestScrollView *scroll = [[TestScrollView alloc] initWithFrame:CGRectMake(0, 100, 400, 600)];
    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    scroll.contentInset = UIEdgeInsetsMake(11, 3, 7, 4);
    scroll.verticalScrollIndicatorInsets = UIEdgeInsetsMake(9, 1, 4, 2);
    scroll.contentSize = CGSizeMake(400, 1200);
    [host addSubview:scroll];
    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentInset.bottom, 107) && near(scroll.contentOffset.y, 707), "bottom pin with composer and existing padding");
    [host updateKeyboardScrollingView:scroll occludedHeight:200];
    check(near(scroll.contentOffset.y, 807), "bottom pin follows keyboard/composer growth");
    scroll.contentOffset = CGPointMake(0, 200);
    [host updateKeyboardScrollingView:scroll occludedHeight:200];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 200), "history position survives inset growth");
    scroll.contentSize = CGSizeMake(400, 1600);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 200), "appended content does not move history reader");
    scroll.contentOffset = CGPointMake(0, 1307);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentSize = CGSizeMake(400, 1800);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 1507), "bottom reader follows appended content");
    [host updateKeyboardScrollingView:scroll occludedHeight:0];
    check(near(scroll.contentOffset.y, 1207), "bottom pin follows dismissal");
    check(near(scroll.contentInset.top, 11) && near(scroll.contentInset.left, 3) && near(scroll.contentInset.right, 4), "non-bottom insets preserved");
    [host updateKeyboardScrollingView:nil occludedHeight:0];
    check(near(scroll.contentInset.bottom, 7) && near(scroll.verticalScrollIndicatorInsets.bottom, 4), "clearing binding restores bottom insets");

    scroll.contentSize = CGSizeMake(400, 100);
    scroll.contentOffset = CGPointMake(0, -11);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, -11), "short conversation clamps to valid top");
    scroll.contentSize = CGSizeMake(400, 400);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 107), "short conversation bottom becomes reachable above composer");
    [host removeKeyboardControl];
    check(near(scroll.contentInset.bottom, 7), "disable restores original padding");

    scroll.contentSize = CGSizeMake(400, 1200);
    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    id<OpeningAnchorTestAccess> controller = testController(host);
    check(controller != nil && near(host.keyboardScrollToBottomThreshold, 60), "refocus default is 60 points");
    host.keyboardScrollToBottomThreshold = 60;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 647);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    [controller captureKeyboardOpeningAnchor];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 907), "inclusive threshold captured before keyboard inset growth");
    host.keyboardScrollToBottomThreshold = 60;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 646);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    [controller captureKeyboardOpeningAnchor];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 646), "outside threshold preserves history");
    host.keyboardScrollToBottomThreshold = 0;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 657);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    [controller captureKeyboardOpeningAnchor];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 657), "zero disables extra refocus behavior");
    host.keyboardScrollToBottomThreshold = 120;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    [controller captureKeyboardOpeningAnchor];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 907), "runtime threshold adjustment");
    host.keyboardScrollToBottomThreshold = 60;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 657);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.pretendTracking = YES;
    [controller captureKeyboardOpeningAnchor];
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 657), "active scroll at opening prevents threshold capture");
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    [controller captureKeyboardOpeningAnchor];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    check(near(scroll.contentOffset.y, 657), "active scroll cancels a pending opening anchor");
    [host removeKeyboardControl];

    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    controller = testController(host);
    TestPan *pan = [TestPan new];
    CGRect shown = CGRectMake(0, 300, 400, 300);
    CGRect dragged = CGRectMake(0, 420, 400, 180);
    check(host.keyboardDismissalScrollCorrection, "dismissal correction enabled by default");
    host.keyboardDismissalScrollCorrection = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 907);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    scroll.contentOffset = CGPointMake(0, 807);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller observeDismissalFrame:dragged panState:UIGestureRecognizerStateChanged];
    pan.simulatedState = UIGestureRecognizerStateEnded;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "active gesture keeps its offset before settling");
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 707), "100-point lead-in is corrected after table rests");
    host.keyboardDismissalScrollCorrection = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 707);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller observeDismissalFrame:dragged panState:UIGestureRecognizerStateChanged];
    pan.simulatedState = UIGestureRecognizerStateEnded;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 407);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 407), "active gesture keeps its offset before settling");
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 407), "history-origin dismissal retains reading position");
    host.keyboardDismissalScrollCorrection = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 907);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    scroll.contentOffset = CGPointMake(0, 807);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    pan.simulatedState = UIGestureRecognizerStateEnded;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "active gesture keeps its offset before settling");
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "table-only scrolling is not corrected");
    host.keyboardDismissalScrollCorrection = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 907);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    scroll.contentOffset = CGPointMake(0, 807);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller observeDismissalFrame:dragged panState:UIGestureRecognizerStateChanged];
    pan.simulatedState = UIGestureRecognizerStateEnded;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "active gesture keeps its offset before settling");
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "dismissal correction can be disabled");
    host.keyboardDismissalScrollCorrection = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 907);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    scroll.contentOffset = CGPointMake(0, 807);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller observeDismissalFrame:dragged panState:UIGestureRecognizerStateChanged];
    pan.simulatedState = UIGestureRecognizerStateCancelled;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "active gesture keeps its offset before settling");
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 607), "cancelled recognizer does not correct");
    host.keyboardDismissalScrollCorrection = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    scroll.contentOffset = CGPointMake(0, 907);
    [host updateKeyboardScrollingView:scroll occludedHeight:300];
    [controller captureDismissalTouch:scroll keyboardFrame:shown];
    [controller observeDismissalFrame:dragged panState:UIGestureRecognizerStateChanged];
    pan.simulatedState = UIGestureRecognizerStateEnded;
    [controller dismissalPanChanged:pan];
    scroll.pretendTracking = YES;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.contentOffset = CGPointMake(0, 607);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.pretendTracking = NO;
    scroll.deferAnimatedOffsets = YES;
    NSUInteger beforeAnimation = scroll.animatedRequests;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(scroll.animatedRequests == beforeAnimation + 1 && near(scroll.requestedAnimatedOffset.y, 707), "correction requests UIKit animated scrolling");
    scroll.contentOffset = CGPointMake(0, 650); // Intermediate UIKit animation frame.
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 650), "inset polling does not snap an intermediate correction frame");
    [controller captureDismissalTouch:nil keyboardFrame:CGRectZero];
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 650), "a new touch cancels correction without snapping the remainder");
    scroll.pretendTracking = YES;
    scroll.contentOffset = CGPointMake(0, 620);
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    scroll.pretendTracking = NO;
    [host updateKeyboardScrollingView:scroll occludedHeight:100];
    check(near(scroll.contentOffset.y, 620), "a new user scroll interrupts the correction");
    scroll.deferAnimatedOffsets = NO;
    [host removeKeyboardControl];

    scroll.frame = host.bounds;
    scroll.contentSize = CGSizeMake(host.bounds.size.width, 2400);
    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    [host layoutIfNeeded];
    CGFloat systemBottom = scroll.adjustedContentInset.bottom - scroll.contentInset.bottom;
    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    [host updateKeyboardScrollingView:scroll occludedHeight:140];
    check(systemBottom > 0, "safe-area test has a real system bottom contribution");
    check(near(scroll.adjustedContentInset.bottom, 7 + MAX(systemBottom, 140)), "safe area is counted once");
    [host removeKeyboardControl];
    check(near(scroll.contentInset.bottom, 7), "repeated setup/teardown restores padding");
    [self runTableHandoffGeometryTests];
    [self runSheetOpeningGeometryTests];
}
- (void)runTableHandoffGeometryTests {
    UIView *host = self.window.rootViewController.view;
    UIScrollView *table = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 60, 350, 400)];
    table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    table.contentInset = UIEdgeInsetsMake(25, 0, 15, 0);
    table.contentSize = CGSizeMake(350, 1800);
    [host addSubview:table];
    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    table.contentOffset = CGPointMake(0, 600);
    [host updateKeyboardScrollingView:table occludedHeight:0];
    UIScrollView *helper = nil;
    for (UIView *v in host.subviews) if ([NSStringFromClass(v.class) isEqualToString:@"DADismissalScrollView"]) helper = (UIScrollView *)v;
    check(helper.contentOffset.y > 500, "history table does not advertise the sheet handoff edge");
    check(helper.contentSize.height > helper.bounds.size.height + 1000, "helper advertises a scrollable table range");
    table.contentOffset = CGPointMake(0, -25);
    [testController(host) tick];
    check(near(helper.contentOffset.y, 0), "real adjusted table top reaches the sheet handoff edge");
    table.contentOffset = CGPointMake(0, -40);
    [testController(host) tick];
    check(near(helper.contentOffset.y, 0), "table top overscroll remains at the handoff edge");
    [host updateKeyboardScrollingView:nil occludedHeight:0];
    check(near(helper.contentOffset.y, 0) && near(helper.contentSize.height, host.bounds.size.height), "unbinding restores the empty helper geometry");
    [host removeKeyboardControl]; [table removeFromSuperview];
}
- (void)runSheetOpeningGeometryTests {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 60, 350, 280)];
    [self.window.rootViewController.view addSubview:host];
    [host addKeyboardPanningWithActionHandler:^(CGRect frame, BOOL opening, BOOL closing) {}];
    [host layoutIfNeeded];
    id<OpeningAnchorTestAccess> controller = testController(host);
    // Allow a rendered baseline before changing the host and guide together.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.6 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            host.frame = CGRectMake(0, 60, 350, 600);
            [host layoutIfNeeded];
        } completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            CALayer *visible = host.layer.presentationLayer;
            check(visible && CGRectGetHeight(visible.bounds) < CGRectGetHeight(host.bounds) - 40,
                  "sheet-opening fixture has a real animated height difference");
            UIView *tracker = [(id)controller valueForKey:@"trackingView"];
            CGFloat oldOverlap = CGRectGetMaxY(host.bounds) - CGRectGetMinY(tracker.layer.presentationLayer.frame);
            check(oldOverlap > 40, "mixed model/presentation geometry reproduces phantom overlap");
            CGRect frame = [controller currentFrame];
            check(frame.size.height < 2, "expanding host with hidden keyboard has no phantom keyboard overlap");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 650 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                check([controller currentFrame].size.height < 2, "settled host still has zero keyboard overlap");
                [host removeKeyboardControl]; [host removeFromSuperview];
                printf("RESULT %d failures\n", failures); fflush(stdout);
                exit(failures ? 1 : 0);
            });
        });
    });
}
@end
@interface TestApp : UIResponder <UIApplicationDelegate>
@end
@implementation TestApp
@end
int main(int argc, char **argv) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(TestApp.class)); } }
