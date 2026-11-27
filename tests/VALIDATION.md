# 1.2.0 development validation

Recorded 2026-10-14. Built with Titanium SDK 13.4.1.GA and Xcode 27.1 beta.

## Automated native checks

The UIKit harness passed all 21 checks on an iPhone 18 Pro simulator running
iOS 27.0. It covers bottom anchoring, composer/keyboard inset changes, history
offsets, appended content, short conversations, retained non-bottom insets,
clearing the binding, disabling/repeating setup, and an actual UIKit safe-area
bottom contribution. See `ChatInsetTests.m` and `run-native.py`.

## Manual Titanium chat checks

The user confirmed these in `example/chat.js` on the iOS 27 simulator:

| Layout | Bottom/composer coordination | History preservation |
| --- | --- | --- |
| Safe area / no extended edges | Passed | Passed |
| Extended / no extended edges | Passed | Passed |
| Safe area / all edges | Passed | Passed |
| Extended / all edges | Passed | Passed |

The checks included showing the keyboard, growing/shrinking multiline input,
interactive panning and reversal, dismissal/reopening, appending content while
reading history, and explicitly returning with Latest. The user also confirmed
the short-conversation case, appending until scrolling became necessary, and
returning to the menu/reopening twice without jumps or crashes.

The isolated consuming app built and loaded module version 1.2.0. Device arm64
and simulator arm64/x86_64 slices, ZIP integrity, manifest identity/version,
and the packaged chat example were verified. The optional TableView bridge
adds no direct link reference to Titanium's TableView native classes.

## Scope

These results cover the isolated example on iOS 27. Physical-device chat
interaction, production-app integration, iPad/floating keyboards, and dynamic
row-height changes above a history reader's viewport are not established by
these checks. No iOS 18/26 simulator runs were performed for this feature.

## Configurable refocus threshold

The extended native checks cover the 60-point default, inclusive boundary before inset growth, history beyond the threshold, disabling with zero, runtime tuning, and active-scroll priority. The user confirmed Alloy composer/panning/history parity before this threshold addition. The user confirmed on the iOS 27 Alloy demo that a position within the 60-point threshold returns to Latest when reopening the keyboard, while older history stays put.

## 1.2.1 dismissal correction (development)

The UIKit harness passes 36 checks on the existing iOS 27 simulator. Synthetic touch/frame/pan-state sequences exercise a 100-point lead-in, waiting for table rest, history-origin gestures, table-only scrolling, disabling correction and recognizer cancellation. These are numeric/state checks, not real interactive gesture proof. The initial manual check confirmed restoration and normal history/table-only scrolling, but reported abrupt motion; see the motion refinement below. The complete previously confirmed 1.2.0 source and packages are preserved separately.

### 1.2.1 motion refinement

The user confirmed automatic restoration but reported an abrupt correction; older-history and table-only scrolling both retained normal behavior. The refinement requests UIKit animated scrolling instead of snapping. Native numeric checks use a controlled scroll-animation test double to verify the animated request, preservation of an intermediate offset, and interruption by user scrolling. The user subsequently confirmed on the iOS 27 Alloy demo that the animated return is smooth and that a new scroll interrupts correctly.

## 1.2.2 animated host geometry

All 40 native checks pass on the existing iOS 27 simulator. Four added checks use a real UIView height animation: the host has a rendered/model height difference; mixing the model bottom with the rendered guide reproduces a phantom overlap; the revised method reports zero keyboard overlap during host expansion with the keyboard hidden; the settled state also reports zero. The previous 36 inset/refocus/dismissal checks still pass. This establishes the geometry regression; the Titanium medium-sheet first-focus visual result remains pending manual confirmation.

The 1.2.2 archive passed ZIP/manifest checks and actual library slice checks (arm64 device, arm64/x86_64 simulator), built with Titanium SDK 13.4.1.GA and Xcode 27.1 beta. SHA-256: `1d82bff31af9b29e7c5be007690c18717d83a9ced8dde76a54f61c436134ac9d`. Installed only in AlloyTestApp. Existing module and demo ZIP hashes match the pre-1.2.2 snapshot; the self-contained 1.2.1 demo apps remain pinned to their included runtime.

### 1.2.2 first manual result

The user confirmed that repeated first focus from medium now moves the composer smoothly into place without the upward-and-back jump. They reported a keyboard-tracking problem in the follow-up regression check. Details are pending; 1.2.2 must not yet be treated as fully validated for interactive tracking.

### Clarification and table-first handoff candidate

The keyboard-tracking answer was corrected: the composer/keyboard regression was not established. The user described the sheet elastically moving during table-origin drags before the table reaches its top. The required policy is table scrolling first, native sheet elasticity at the real table top while focused, and sheet dismissal handoff at top when keyboard hidden and dismissal enabled. The candidate mirrors table adjusted-top distance/range in the helper; geometry and cleanup checks were added. Interactive confirmation remains pending.

The revised table-handoff candidate passes 45 native checks, including five helper range/top-edge/unbind checks plus the prior 40 regressions. Current ZIP SHA-256: `5bd72e9268b5ba30023e2a16908f6f8b2f20bb59f9ed80b2de4f13535e063c31`. The previous opening-fix-only 1.2.2 archive is preserved at `/private/tmp/keyboard-1.2.2-opening-fix.zip`. Older published/development module and demo archives retain their pre-1.2.2 hashes. Empty-helper interference with native sheet handoff is a hypothesis supported by its previous always-at-top geometry; actual UIKit touch-driven behavior remains pending manual confirmation.

### User-confirmed table-first handoff on iOS 27

The user confirmed the current 1.2.2 candidate on iPhone 18 Pro: with keyboard focused, only the table scrolls until it reaches its top; with keyboard hidden, scrolling hands off to sheet resizing/dismissal at the table's top. Composer-margin keyboard panning/reversal and smooth first focus from medium remain correct. These manual simulator results validate the targeted handoff behavior with Bottom Sheet 2.3.0. Physical-device and other iOS-version checks were not performed.


### 1.2.3 page-sheet motion candidate (2026-11-11)

The reported device recording shows a focused TextField and locked footer in a
standard page-sheet modal with `forceModal: true` and interactive sheet dismissal
disabled. Elastic sheet motion causes rapid locked-view position corrections.
The 1.2.3 candidate converts the keyboard layout boundary through window space
into the rendered host coordinate system when ancestor/host movement creates a
model/presentation mismatch. It uses this correction during a drag and stationary
keyboard sheet spring-back, retaining existing keyboard show/hide sampling.
No public API or application integration changes are required.

The complete pre-change 1.2.2 checkout (excluding Git/build caches) and all existing
distributions are backed up at `../TiDAKeyboardControl-1.2.2-preserved-2026-11-11`.
`BACKUP-SHA256.json` records the preserved file hashes. The prior 1.2.2 ZIP remains
`5bd72e9268b5ba30023e2a16908f6f8b2f20bb59f9ed80b2de4f13535e063c31`.

The native regression harness compiles with five additional ancestor-translation
checks: real presentation offset, failure of uncorrected local geometry, fixed
keyboard alignment during drag, consistent spring-back alignment, and continued
tracking when the keyboard itself moves. These checks were NOT executed; the
previous 45 checks have not been rerun for this candidate. Compilation/package
validation does not establish that the recorded jitter is resolved.

User testing remains pending: repeat stationary-keyboard upward/downward sheet
bounces and spring-back; then verify genuine keyboard dismissal/reversal,
ordinary show/hide, safe-area/extended edges, and repeated close/reopen. Include
both simulator and physical-device checks. DateMaps and installed modules were
not changed; the user will integrate and test the new package manually.

Final package validation: ZIP CRC and source/embedded manifest match passed; actual static libraries contain arm64 device and arm64/x86_64 simulator slices. Built with Titanium SDK 13.4.1.GA and Xcode 27.1 beta (27A9269). Package SHA-256: `22c03078f34e21361ae7cd63ed1ad3c61ec205e139e458680220a0a10d09f7b4`. No installation, simulator launch, GitHub push, tag, or release was performed.


### 1.2.4 ordinary keyboard animation candidate (2026-11-11)

The user reports that 1.2.3 does not improve modal rubber-band jitter. A new
recording also shows rigid/stepped locked-view movement during ordinary keyboard
presentation. The 1.2.4 candidate restores the preserved 1.2.2 frame-sampling
implementation and removes the unconfirmed 1.2.3 coordinate branch.

A narrow bridge hook requests native UIKit show/hide transform animations using
UIKeyboardAnimationDurationUserInfoKey and UIKeyboardAnimationCurveUserInfoKey.
It applies only when no keyboardScrollingView is bound. Direct interactive
tracking, native TableView coordination, undocked keyboards, and missing/zero
animation durations retain the established path. Display ticks stop overwriting
the animated transform until the reported duration ends. A pan, table binding,
or changed host geometry cancels the transform animation and resumes direct
tracking. Teardown cancels only the owned transform animation. No delayed
completion callback retains or dereferences a closing Titanium proxy.

A complete pre-change 1.2.3 source/package backup is at
`../TiDAKeyboardControl-1.2.3-preserved-2026-11-11`; file hashes are recorded in
BACKUP-SHA256.json. Its ZIP SHA-256 remains
`22c03078f34e21361ae7cd63ed1ad3c61ec205e139e458680220a0a10d09f7b4`.
The earlier 1.2.2 backup/distribution is unchanged.

The native harness compiles with six added contract checks for target coordinate
conversion, reported duration/curve, interruptible animation options, hide target,
missing timing fallback, and bound-table fallback. These tests have NOT been
executed. The Titanium bridge/package build is separate evidence from UIKit
runtime behavior. The user will test simulator and physical-device behavior;
no consumer app or installed module has been modified.

Pending manual cases: ordinary show/hide on a fixed-size window; repeated quick
focus/blur; begin a real dismissal pan during keyboard opening, reverse and
release; safe-area/extended-edge layouts; sheet resizing/opening fallback;
bound-table bottom/history coordination; close/reopen while animating. The
page-sheet rubber-band jitter remains a separate unresolved issue.

Animation handoff also waits for the sampled guide to reach the native target after the reported duration, avoiding a backward step to a trailing presentation sample. An additional wait is bounded by the same reported duration; pan/host changes still interrupt immediately.

Final package: ZIP CRC and source/embedded manifest checks passed. Actual library slices are arm64 device and arm64/x86_64 simulator. Built with Titanium SDK 13.4.1.GA and Xcode 27.1 beta (27A9269). SHA-256: `28f2b209c5677909c07bddc5065a311205f239b077fb0267450abc068bbefa5c`. No app/module installation, simulator/device test, GitHub push, tag, or release was performed.
