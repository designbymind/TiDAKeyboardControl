# Native inset regression checks

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
