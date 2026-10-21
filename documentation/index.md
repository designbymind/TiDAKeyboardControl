# TiDAKeyboardControl Module

Version 1.1.0 requires iOS 18 or later and uses native UIKit
interactive dismissal. See [the focused example](../example/panning.js) for safe-area and extended-edge
test modes. Chat content insets and automatic composer sizing are separate work.

## Description

Do you want to create a perfect clone of the iMessage compose interface? ***Fear no more!*** You can now respond to keyboard events (show, hide and interactive changes) and customize how much space will be used as an offset during interactive panning.

Titanium SDK wrapper for the awesome [DAKeyboardControl][dakc] from [@danielamitay][da]! (iOS only)

## Accessing the TiDAKeyboardControl Module

What you have to do is just install the module, nothing more!

Thanks to the native implementation using Objective-C categories to extend classes, TiDAKeyboardControl Module does not need the **require( )** method to access the module from JavaScript.


## Usage

### TableView integration (1.2.0 development)

Set `window.keyboardScrollingView` to a `Ti.UI.TableView`, alongside
`keyboardPanning: true` and `lockedViews`. The module adjusts bottom content and
indicator insets from actual keyboard/composer overlap. The table frame and
delegate are retained. Existing bottom padding is preserved; UIKit safe-area
padding is counted once. Readers within 12 points of the bottom stay pinned;
other readers keep their offset, subject to the valid scroll range. Assign
`null` or disable panning to restore original bottom insets. App code should
not also write bottom insets while this integration is enabled.

See [the isolated chat example](../example/chat.js). Composer sizing remains
application-owned; the example grows its TextArea to a cap and then scrolls
the text internally.

### Properties
- ``keyboardTriggerOffset``: *number*, 
How much space must be took on top of the keyboard.

- ``keyboardPanning``: *boolean*, This activates the panning feature.
- ``lockedViews``: *[View]*, Automatically add the specified View as a locked view.

The module manages each locked view's `transform`. Keep the view anchored to the
bottom of its parent, and update `keyboardTriggerOffset` from its measured height
after layout. Translation accounts for the actual parent bounds, including
`extendSafeArea` and `extendEdges` on Titanium windows.

### Events

`keyboardchange` provides numeric `x`, `y`, `width`, and `height` values in the
host view's local coordinate system. A hidden keyboard has `height: 0` and `y`
at the bottom of the host. Identical frames do not generate repeated events.
For smooth attached-view movement, use `lockedViews`; JavaScript event delivery
is suitable for observing changes but can arrive later than native updates.

### Cleanup

Set `keyboardPanning` to `false` when closing the host window to remove keyboard
tracking and interactive-dismissal setup. It can be enabled again on a live
window. The focused example exercises both toggling and close/reopen behavior.

### TextArea gestures (1.1.1 development)

A drag starting in a TextArea contained in a locked view scrolls the TextArea
without interactively dismissing the keyboard, even if the finger subsequently
leaves the TextArea. Drag on the surrounding bar to pan the keyboard. TextAreas
outside locked views retain the existing gesture behavior.


An extensive example can be found in `example/app.js`, the following one just acts as an overview.
To clear up every doubts please read [this](../example/README.md).


```js

var textarea = Ti.UI.createTextArea({
	right: 0,
	bottom: 0,
	left: 0,
	scrollable: false,
	suppressReturn: false,
	height: Ti.UI.SIZE,
});

var window = Ti.UI.createWindow({
	keyboardTriggerOffset: 0,
	keyboardPanning: true,
	lockedViews: [ textarea ]
});

window.addEventListener('close', function (event) {
	// Very important! Releases what needs to be released
	event.source.keyboardPanning = false;
});

window.add(textarea);

// The window is now the host for keyboard events
window.addEventListener('keyboardchange', function (event) {
	Ti.API.error("Notification of keyboard change: y=" + event.y + " height="+event.height);
});

// Multiline text-area
textarea.addEventListener('postlayout', function (event) {
	window.keyboardTriggerOffset = event.source.rect.height;
});

window.open();
```


## Author

Kudos to @danielamitay for the development of DAKeyboardControl.

Humbly made by the spry ladies and gents at SMC.


[dakc]: https://github.com/danielamitay/DAKeyboardControl
[da]: http://danielamitay.com


## License

This library, *TiDAKeyboardControl*, is free software ("Licensed Software"); you can
redistribute it and/or modify it under the terms of the [GNU Lesser General
Public License](http://www.gnu.org/licenses/lgpl-2.1.html) as published by the
Free Software Foundation; either version 2.1 of the License, or (at your
option) any later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; including but not limited to, the implied warranty of MERCHANTABILITY,
NONINFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General
Public License for more details.

You should have received a copy of the [GNU Lesser General Public
License](http://www.gnu.org/licenses/lgpl-2.1.html) along with this library; if
not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth
Floor, Boston, MA 02110-1301 USA

### Keyboard refocus threshold (1.2.0)

`window.keyboardScrollToBottomThreshold = 60` sets the maximum distance, in points,
from the table's bottom that will return to the latest message when the keyboard
opens. The default is 60; use any finite nonnegative number, or `0` to disable
this additional refocus behavior. The distance is captured before keyboard inset
changes, including the current composer and safe-area insets. History farther
away stays put, and active dragging/deceleration takes precedence. Repeated
keyboard notifications while already open do not trigger this behavior.
This requires `keyboardScrollingView`; the existing 12-point bottom-following
behavior for content/composer changes is separate and remains unchanged.

### Dismissal-pan scroll correction (1.2.1)

`window.keyboardDismissalScrollCorrection = true` (default) remembers whether a
table-origin drag began at the latest message. If that same gesture actually
moves the keyboard, the table returns to the latest message after the gesture,
keyboard animation, and table deceleration settle. This compensates for the
scrolling before the finger reaches the composer, including lead-ins greater
than the refocus threshold. A reversed keyboard pan also restores the bottom
once settled. A cancelled recognizer, a new touch, a drag starting in history,
or a gesture that never moves the keyboard does not trigger correction.
Set the property to `false` to compare normal scrolling. This requires
`keyboardScrollingView` and is independent of `keyboardScrollToBottomThreshold`.
The latest bottom position uses the current composer, keyboard and safe area.

The 1.2.1 correction uses UIKit animated scrolling after settling, and can be interrupted by a new touch/scroll. Per-frame inset updates preserve the intermediate animation offsets. Reduce Motion uses an immediate correction.

### Animated presentation resizing (1.2.2)

Keyboard opening overlap now measures the rendered host bottom and keyboard-guide position in the same coordinate space before translating the result into Titanium's model coordinates. This avoids a phantom keyboard overlap while a medium sheet expands to large. Interactive drags continue using the current keyboard guide rather than the previous presentation frame. No new JavaScript property is required.

### Table-origin sheet handoff (1.2.2 candidate)

The empty dismissal helper now mirrors the bound table's scrollable range and adjusted distance from the top. It should no longer advertise an at-top scroll position while the table is reading history. The real table's delegate and content ownership remain unchanged. The intended native-sheet policy is table scrolling first; sheet bounce/handoff only at the adjusted top, with actual dismissal additionally governed by keyboard focus and the sheet's dismissal policy. Native geometry checks establish the helper state; touch-driven handoff still requires manual validation.
