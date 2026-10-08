//
//  DAKeyboardControl.h
//  DAKeyboardControlExample
//
//  Created by Daniel Amitay on 7/14/12.
//  Copyright (c) 2012 Daniel Amitay. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^DAKeyboardDidMoveBlock)(CGRect keyboardFrameInView, BOOL opening, BOOL closing);

/** Keyboard awareness and native interactive dismissal for UIView/UIScrollView
 hosts on iOS 18 and later. Frames are local to the host, with zero height when
 the keyboard is dismissed. No private keyboard views are accessed.
 */

@interface UIView (DAKeyboardControl)

/** Padding above the keyboard where the native dismissal gesture engages.
 Typically the attached view's measured height. Negative values are clamped to 0.
 */
@property (nonatomic) CGFloat keyboardTriggerOffset;
@property (nonatomic, readonly) BOOL keyboardWillRecede;

/** Adding pan-to-dismiss (functionality introduced in iMessages)
 @param didMoveBlock called everytime the keyboard is moved so you can update
 the frames of your views
 @see addKeyboardNonpanningWithActionHandler:
 @see removeKeyboardControl
 */
- (void)addKeyboardPanningWithActionHandler:(DAKeyboardDidMoveBlock)didMoveBlock;
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

/** Returns the keyboard frame in the view */
- (CGRect)keyboardFrameInView;
@property (nonatomic, readonly, getter = isKeyboardOpened) BOOL keyboardOpened;

/** Convenience method to dismiss the keyboard */
- (void)hideKeyboard;

@end
