
Example code for TiDAKeyboardControl

## Complete chat test apps (1.2.0 development)

- [Classic project ZIP](KeyboardChat-Classic-1.2.0.zip): the same chat fixture used for the iOS 27 interaction checks.
- [Alloy project ZIP](KeyboardChat-Alloy-1.2.0.zip): equivalent XML views, TSS styles, and menu/chat controllers.
- Editable projects: [`apps/KeyboardChatClassic`](apps/KeyboardChatClassic) and [`apps/KeyboardChatAlloy`](apps/KeyboardChatAlloy).

Each archive includes its own app-local 1.2.0 module runtime and license, plus a README with setup and the five test cases. Unzip, enter the project directory, and run `ti build -p ios -T simulator --sdk 13.4.1.GA`. The Alloy project also requires the Alloy CLI. No global module installation is required. Use an existing iOS 27 simulator for testing.

The Classic chat behavior passed the manual checks documented in `../tests/VALIDATION.md`. The user confirmed Alloy composer/panning/history parity on iOS 27 before the refocus-threshold addition; the user also confirmed the 60-point refocus behavior: near-bottom returns to Latest while older history stays put. Native module code is unchanged by this conversion. Build outputs and generated Alloy Resources are excluded from the archives.

====================================

`chat.js` (1.2.0 development)
---------------------------

Run `require('chat')();` to test optional native TableView inset coordination.
Open a layout at the latest message, show the keyboard, grow/shrink the input,
pan down and reverse, dismiss, and reopen. Scroll up to read older messages and
repeat; the same visible messages should keep their position. Append should
follow only when already at the bottom. Latest explicitly returns to the end.
The short-conversation case checks content smaller than the viewport. Repeat
with the other safe-area/edge modes and cancel a back swipe with input focused.
Close/reopen screens to exercise inset restoration and repeated setup.

`panning.js`
------------

This is the focused example for version 1.1.1 development on iOS 18 and later. Install the
module and add it to `tiapp.xml` as described in the [main README](../README.md).
Copy `panning.js` into a Classic app's `Resources` directory, then run:

```js
require('panning')();
```

The menu contains TextField and TextArea cases for all four combinations of
`extendSafeArea` (`false`/`true`) and `extendEdges` (none/all). In each mode, tap the input, drag downward from the
blue margin, reverse a partial drag, fully dismiss, and reopen the keyboard.
The blue bar should remain attached throughout. Also test Disable/Enable and
return to the menu to reopen the same mode.

In TextArea modes, scroll the prefilled multiline text in both directions. The
keyboard and blue bar should stay still. A drag that begins in the TextArea
should remain a text gesture if the finger leaves it. Then start a fresh drag
on the blue margin and confirm normal keyboard panning and reversal.

With the keyboard shown, begin a back swipe from the left edge and cancel it.
If the keyboard stays hidden, the blue bar should remain at the bottom without
jumping upward. Refocus the input and confirm normal keyboard panning still
works. Repeat with both a TextField and a TextArea.

The example logs focus, blur, and keyboard visibility changes, and checks that
the `keyboardchange` frame values are finite numbers. The four TextField checks
passed for 1.1.0 in simulators running iOS 18.4, 26.5, and 27.0. Toggle and repeated
screen-reopening checks passed on iOS 27.0. Physical-device testing is pending.
The 1.2.0 chat example additionally passed growing TextArea/panning checks in
all four layouts on iOS 27.0, including history preservation and reopening.

This example covers keyboard panning. Table content insets and automatic
composer resizing are separate features.

The original examples below are retained for reference.

`navbar.js`
-----------

Run `require('navbar')();` in a Classic app to compare otherwise identical
NavigationWindow screens with keyboard panning off/on. Check initial opening,
scrolling messages beneath the bar, returning to the top with the Top button,
and cancelling a back swipe while the table is at the top. With panning on,
also check multiline text scrolling and keyboard panning from the blue margin.
The real table should drive the navigation-bar effect in both modes.


`automatic.js`
--------------

This example file shows the preferred way of using this module.

Instead of listening to `keyboardchange` events and moving the ‘toolbar’ accordingly, we just let the module manage it for us.

This happens in three steps.

```js
Ti.UI.createWindow({              /* 1 */
    keyboardPanning: true,        /* 2 */
    lockedViews: [ textareaview ] /* 3 */
});
```

1.	Create a container view which will be the host for keyboard notifications;
2.	setup the notifications with `keyboardPanning: true`;
3.	add our ‘toolbar’ to the list of views whose `.transform` will be managed by *TiDAKeyboardControl*.

`manual.js`
-----------

This example code uses the `"keyboardchange"` event in the host container view to update manually the `.transform` property of our ‘toolbar’.

This kind of implementation may cause a little glitch scrolling up and down the keyboard.
The slowness during the toolbar's repositioning is caused by a performance issue but shows how we can do pretty whatever we want with this module.

## Refocus threshold tuning

Both runnable chat projects explicitly set `keyboardScrollToBottomThreshold = 60` in their chat controller. Change this finite nonnegative point value to tune how close the table must be to the bottom to return to the latest message when reopening the keyboard. Set it to 0 to disable this extra refocus behavior. Positions beyond the threshold remain unchanged.

## 1.2.1 dismissal-correction apps

The current editable projects use 1.2.1. Separate `KeyboardChat-Classic-1.2.1.zip` and `KeyboardChat-Alloy-1.2.1.zip` downloads include that app-local runtime. Original 1.2.0 ZIPs remain unchanged. Test a table-origin keyboard dismissal beginning at Latest, starting about 100 points above the composer, and check the final resting position. Reverse a partial pan, repeat from history, and compare `keyboardDismissalScrollCorrection = false`. On the iOS 27 Alloy demo, the user confirmed restoration, normal history/table-only scrolling, and—after motion refinement—a smooth animated return that yields to a new scroll.
