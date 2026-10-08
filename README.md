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

### Version 1.1.0

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
in all four layout modes on iOS 18.4, 26.5, and 27.0. On iOS 27.0, disabling and
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
