# Keyboard/TableView chat demo (Classic)

Self-contained iOS Titanium project with the app-local TiDAKeyboardControl 1.2.1 development module. No global module installation or network/backend is needed. The native runtime, configuration and license are included under `modules/iphone/it.smc.dakeyboardcontrol/1.2.1`; duplicate module examples/documentation are omitted.

## Run

Install Titanium CLI and SDK 13.4.1.GA, a compatible Xcode, and Node.js.
Unzip the project, enter this directory, and run:

```sh
ti build -p ios -T simulator --sdk 13.4.1.GA
```

Choose an existing iOS 27 simulator. The module supports iOS 18+, but this chat demo's interaction validation was performed on iOS 27. The two apps have separate identifiers so they can coexist.

## Test

- Open each of the four safe-area/extended-edge modes and Short conversation.
- At the latest message, show the keyboard and type multiple lines (input grows from 42 to 160 points, then scrolls).
- Pan from the blue margin, reverse mid-drag, dismiss, and reopen. Gestures starting inside the TextArea should scroll its text rather than pan the keyboard.
- Read older messages and grow/shrink the input, show/hide the keyboard, and tap Append. History should stay put. Tap Latest to return to the bottom.
- Test short content until it becomes scrollable, cancel a back swipe while editing, then close/reopen the screen twice.

The module manages bottom content/indicator insets and preserves the reading position; the application manages composer height. Append does not explicitly scroll, and Latest does.

## Source

`Resources/app.js` opens `Resources/chat.js`, copied unchanged from the tested Classic fixture.

The Classic behavior passed the manual iOS 27 checks above. The user also confirmed Alloy interaction parity on iOS 27 before the refocus-threshold addition. The user subsequently confirmed the 60-point refocus behavior on the iOS 27 Alloy demo: near-bottom returns to Latest while older history stays put.

## Refocus tuning

Set `keyboardScrollToBottomThreshold` in the chat controller (Alloy) or `Resources/chat.js` (Classic). The examples explicitly use 60 points. Use 0 to disable this extra refocus behavior. After dismissing the keyboard from the latest message, scroll a small distance away and focus again: within the threshold it returns to the latest message; farther-away history stays put. Measurement uses the pre-opening insets, and active scrolling wins.

## Dismissal correction (1.2.1)

With the keyboard shown and the table at Latest, start a downward table drag roughly 100 points above the blue composer. Continue into a keyboard dismissal and release. Once scrolling and the keyboard settle, the latest message should be above the composer again. Also try reversing the pan before release; the bottom should be restored once the keyboard settles. Repeat from older history: the module should preserve normal table scrolling. A table drag that never moves the keyboard should scroll normally. Set `keyboardDismissalScrollCorrection` to false in the chat controller to compare. On the iOS 27 Alloy demo, the user confirmed restoration and normal history/table-only scrolling.

The 1.2.1 correction now uses UIKit animated scrolling, with interruption by new touches or scrolling. The original snap restored correctly but was reported as abrupt; the user confirmed the revised return is smooth and yields to a new scroll.
