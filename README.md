TiDAKeyboardControl 
===================

[![Built for Titanium SDK][ti-badge]][ti]
[![Available through gitTio][gittio-badge]][gittio-page]

[ti-badge]: http://www-static.appcelerator.com/badges/titanium-git-badge-sq.png
[ti]: http://www.appcelerator.com/titanium/
[gittio-badge]: http://gitt.io/badge.png
[gittio-page]: http://gitt.io/component/it.smc.dakeyboardcontrol

Do you want to create a perfect clone of the iMessage compose interface? ***Fear no more!*** You can now respond to keyboard events (show, hide, and realtime interactive changes) and customize how much space will be used as an offset during interactive panning.

Titanium SDK wrapper for the awesome [DAKeyboardControl][dakc] from [@danielamitay][da]! (iOS only)

### Version 1.2.2 development

Opt a TableView into native chat inset coordination by setting
`keyboardScrollingView` on the host window:

```js
win.lockedViews = [composer];
win.keyboardScrollingView = table;
win.keyboardPanning = true;
composer.addEventListener('postlayout', function () {
    win.keyboardTriggerOffset = composer.rect.height;
});
```

The table keeps its full frame. Its bottom content and indicator insets follow
the keyboard and visible locked views, with UIKit's existing safe-area
contribution accounted for. Existing bottom padding is retained. Readers within
12 points of the bottom stay anchored there; readers viewing older messages
keep their offset as the composer/keyboard changes. Explicit app scrolling
remains supported. Setting `keyboardScrollingView` to `null` or disabling
panning restores the original bottom insets.

This first integration supports `Ti.UI.TableView`. It owns bottom inset updates
while enabled; avoid competing app/module inset writers. Top/left/right insets,
the table delegate, and view containment are preserved. The coordinator checks
layout once per display frame while the opted-in host is attached, including
with the keyboard hidden, to track asynchronous row measurement and composer
resizing. Without `keyboardScrollingView`, existing behavior is unchanged.

Run `require('chat')();` using `example/chat.js` for long/short conversations,
four safe-area/edge layouts, growing TextArea, Append, and Latest controls.
The TextArea height is capped in the example; the module measures the actual
locked view and does not prescribe a composer design. Package:
`dist/it.smc.dakeyboardcontrol-iphone-1.2.2.zip`.

On iOS 27.0, manual simulator checks passed for all four safe-area/edge layouts:
keyboard panning/reversal, composer growth/shrinkage, bottom anchoring, history
preservation, Append, and Latest. Short conversations, growth into scrollable
content, and repeated screen reopening also passed. The standalone native
inset harness passed all 14 checks. See [validation details](tests/VALIDATION.md).

### Fixes included from 1.1.1 development

Drags that begin in a TextArea inside a `lockedViews` view are excluded from
interactive keyboard dismissal for the entire drag. The TextArea keeps its
normal scrolling and selection gestures. Drag the surrounding bar to pan the
keyboard. This applies automatically; no additional JavaScript property is
required. TextAreas elsewhere in the window are unaffected.

Confirmed keyboard dismissal now stops tracking even when the input remains
focused. Restoring focus during a cancelled navigation swipe does not restart
locked-view movement until a new keyboard presentation begins.

The empty dismissal helper disables its own system-bar scroll-edge effects on
iOS 26 and later and does not participate in status-bar scroll-to-top. The real
table/scroll view retains its normal effects. `example/navbar.js` compares
navigation appearance with keyboard panning off/on.

`example/panning.js` now includes scrollable multiline TextArea cases for all
four safe-area/edge combinations. Growing TextArea and panning behavior has
also been verified through the 1.2.0 chat example across all four layouts.
Building the current source produces
`dist/it.smc.dakeyboardcontrol-iphone-1.1.1.zip`.

### Published version 1.1.0

The keyboard backend now uses UIKit's interactive scroll dismissal and
`UIKeyboardLayoutGuide`, with an iOS 18 minimum deployment target. The intended
runtime targets are iOS 18, 26, and 27. Existing `keyboardPanning`, `lockedViews`,
`keyboardTriggerOffset`, and `keyboardchange` names are preserved.

Set `keyboardTriggerOffset` to the attached view's measured height to let the
dismissal gesture engage above the keyboard. Locked-view translation uses its
actual native parent bounds, including Titanium's `extendSafeArea` and
`extendEdges` layout. The module does not change those window properties or add
table content insets.

The focused `example/panning.js` test has four safe-area/edge-extension modes,
keyboard show/hide, a panning toggle, and close/reopen. It can be run from a
Classic app with the module in `tiapp.xml`:

```js
require('panning')();
```

Build the module using the current Titanium CLI rather than the legacy Python
packager:

```sh
ti build -p ios --build-only --project-dir . --sdk 13.4.1.GA --no-prompt
```

The package is written to `dist/it.smc.dakeyboardcontrol-iphone-1.1.0.zip`.
Simulator testing confirmed smooth dragging, reversal, dismissal, and reopening
in all four TextField layout modes on iOS 18.4, 26.5, and 27.0. On iOS 27.0, disabling and
reenabling panning and repeatedly closing/reopening the screen also passed.
The module builds with Titanium SDK 13.4.1.GA for arm64 devices and
arm64/x86_64 simulators. Physical-device testing remains outstanding.

### Installation

Download `it.smc.dakeyboardcontrol-iphone-1.1.0.zip` from the
[iOS v1.1.0 release][rls]. Extract it into your Titanium app's root directory
for an app-local installation. The archive contains
`modules/iphone/it.smc.dakeyboardcontrol/1.1.0/`.

Add the module inside the existing `<modules>` element in `tiapp.xml`:

```xml
<module platform="iphone" version="1.1.0">it.smc.dakeyboardcontrol</module>
```

Set `<min-ios-ver>18.0</min-ios-ver>` inside `<ios>`. Version 1.1.0 was built and
tested with Titanium SDK 13.4.1.GA. Clean the consuming app after replacing a
previously installed package with the same version.

[rls]: https://github.com/designbymind/TiDAKeyboardControl/releases/tag/ios-v1.1.0

### Example

Copy `example/panning.js` into a Classic app's `Resources` directory and call
`require('panning')();` from `Resources/app.js`. The module must be installed and
listed in `tiapp.xml` as shown above.

The [example folder][exm] also contains the original automatic and manual
examples. Use the focused panning example to check modern safe-area layouts.

[exm]: https://github.com/designbymind/TiDAKeyboardControl/tree/master/example


Usage overview
--------------

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
	// How much space must be took on top of the keyboard
	keyboardTriggerOffset: 0,
	// This activates the panning feature
	keyboardPanning: true,
	// Automatically add the textarea as a locked view
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


Credits
-------

Kudos to @danielamitay for the development of DAKeyboardControl.

Humbly made by the spry ladies and gents at SMC.


[dakc]: https://github.com/danielamitay/DAKeyboardControl
[da]: http://danielamitay.com


License
-------

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
