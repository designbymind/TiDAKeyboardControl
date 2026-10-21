//
//  DAKeyboardControl.h
//  DAKeyboardControlExample
//
//  Created by Daniel Amitay on 7/14/12.
//  Copyright (c) 2012 Daniel Amitay. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^DAKeyboardDidMoveBlock)(CGRect keyboardFrameInView, BOOL opening, BOOL closing);
typedef BOOL (^DAKeyboardTouchFilterBlock)(UIView *touchedView);

/** Keyboard awareness and native interactive dismissal for UIView/UIScrollView
 hosts on iOS 18 and later. Frames are local to the host, with zero height when
 the keyboard is dismissed. No private keyboard views are accessed.
 */

@interface UIView (DAKeyboardControl)

/** Padding above the keyboard where the native dismissal gesture engages.
 Typically the attached view's measured height. Negative values are clamped to 0.
 */
@property (nonatomic) CGFloat keyboardTriggerOffset;
/** Distance from the bottom eligible for reanchoring when the keyboard opens.
 Defaults to 60 points; 0 disables this additional refocus behavior. */
@property (nonatomic) CGFloat keyboardScrollToBottomThreshold;
/** Restore a bottom reader after table-origin interactive dismissal. Default YES. */
@property (nonatomic) BOOL keyboardDismissalScrollCorrection;
@property (nonatomic, readonly) BOOL keyboardWillRecede;

/** Adding pan-to-dismiss (functionality introduced in iMessages)
 @param didMoveBlock called everytime the keyboard is moved so you can update
 the frames of your views
 @see addKeyboardNonpanningWithActionHandler:
 @see removeKeyboardControl
 */
- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)didMoveBlock;
/** Filter initial touches received by the dismissal helper without changing
 the touched control's own gestures. Returning NO excludes the entire drag.
 */
- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)didMoveBlock
                       shouldReceiveTouch:(DAKeyboardTouchFilterBlock)touchFilter;
- (void)addKeyboardPanningWithFrameBasedActionHandler:(DAKeyboardDidMoveBlock)didMoveFrameBasesBlock
                         constraintBasedActionHandler:(DAKeyboardDidMoveBlock)didMoveConstraintBasesBlock;

/** Adding keyboard awareness (appearance and disappearance only)
 @param didMoveBlock called everytime the keyboard is moved so you can update
 the frames of your views
 @see addKeyboardPanningWithActionHandler:
 @see removeKeyboardControl
 */
- (void)addKeyboardNonpanningWithActionHandler:(DAKeyboardDidMoveBlock)didMoveBlock;
- (void)addKeyboardNonpanningWithFrameBasedActionHandler:(DAKeyboardDidMoveBlock)didMoveFrameBasesBlock
                            constraintBasedActionHandler:(DAKeyboardDidMoveBlock)didMoveConstraintBasesBlock;

/** Remove the keyboard action handler
 @note You MUST call this method to remove the keyboard handler before the view
 goes out of memory.
 */
- (void)removeKeyboardControl;

// Titanium bridge support: coordinate an optional native table without moving
// it into the helper scroll view or replacing its delegate.
- (void)updateKeyboardScrollingView:(UIScrollView *)scrollView occludedHeight:(CGFloat)height;
- (void)refreshKeyboardControl;

/** Returns the keyboard frame in the view */
- (CGRect)keyboardFrameInView;
@property (nonatomic, readonly, getter = isKeyboardOpened) BOOL keyboardOpened;

/** Convenience method to dismiss the keyboard */
- (void)hideKeyboard;

@end
