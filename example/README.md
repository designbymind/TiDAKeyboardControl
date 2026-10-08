
Example code for TiDAKeyboardControl
====================================

`panning.js`
------------

This is the focused example for version 1.1.0 on iOS 18 and later. Install the
module and add it to `tiapp.xml` as described in the [main README](../README.md).
Copy `panning.js` into a Classic app's `Resources` directory, then run:

```js
require('panning')();
```

The menu contains all four combinations of `extendSafeArea` (`false`/`true`) and
`extendEdges` (none/all). In each mode, tap the field, drag downward from the
blue margin, reverse a partial drag, fully dismiss, and reopen the keyboard.
The blue bar should remain attached throughout. Also test Disable/Enable and
return to the menu to reopen the same mode.

The example logs focus, blur, and keyboard visibility changes, and checks that
the `keyboardchange` frame values are finite numbers. The four-mode checks
passed in simulators running iOS 18.4, 26.5, and 27.0. Toggle and repeated
screen-reopening checks passed on iOS 27.0. Physical-device testing is pending.

This example covers keyboard panning. Table content insets and automatic
composer resizing are separate features.

The original examples below are retained for reference.


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
