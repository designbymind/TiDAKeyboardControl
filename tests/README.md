# Native inset regression checks

The 1.2.4 source adds six keyboard-notification contract checks to the preserved
45 baseline checks. The harness compiles but has not been executed for this
candidate. The five unvalidated 1.2.3 sheet-translation checks were removed with
that implementation after the user reported no visual improvement.

The standalone UIKit harness exercises bottom anchoring, history offsets,
appended content, short content, preserved padding, actual safe-area adjustment,
repeated teardown, configurable refocus boundaries, and active-scroll precedence. It compiles the module's real keyboard backend.

Run on an existing booted arm64 simulator, selecting the desired Xcode per command:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1-Beta.app/Contents/Developer \
python3 tests/run-native.py --device <simulator-UDID>
```

This installs a separate `com.designbymind.chatinsettests` test app. It does not
exercise Titanium bridge resolution, interactive keyboard motion, or animation
appearance. Use `example/chat.js` for those simulator checks. No simulator is
created by the script.
