var args = arguments[0] || {};
var count = args.short ? 2 : 45;
var initialized = false;
var rows = [];

$.chat.applyProperties({
    title: args.short ? 'Short conversation' : 'Chat history',
    extendSafeArea: !!args.extended,
    extendEdges: args.edges ? [Ti.UI.EXTEND_EDGE_ALL] : []
});
for (var i = 1; i <= count; i++) {
    rows.push({
        title: 'Message ' + i + '\nA sample conversation message.', height: 72,
        color: '#111111', backgroundColor: i % 2 ? '#ffffff' : '#eef2f7',
        selectionStyle: Ti.UI.SELECTION_STYLE_NONE
    });
}
$.messages.data = rows;
// The native module owns overlap insets and reading-position preservation.
// The application owns the TextArea/composer size and explicit Latest action.
$.chat.keyboardPanning = true;
$.chat.lockedViews = [$.composer];
$.chat.keyboardScrollingView = $.messages;
$.chat.keyboardDismissalScrollCorrection = true; // Set false to compare uncorrected dismissal.
$.chat.keyboardScrollToBottomThreshold = 60; // Points; tune here, or use 0 to disable refocus snapping.

function onInputChange(event) {
    var height = Math.max(42, Math.min(160, event.contentHeight || 42));
    $.input.height = height;
    $.composer.height = height + 38;
}
function onComposerLayout() {
    $.chat.keyboardTriggerOffset = $.composer.rect.height;
}
function hideKeyboard() { $.input.blur(); }
function showLatest() {
    $.messages.scrollToIndex(count - 1, { animated: true, position: Ti.UI.TableViewScrollPosition.BOTTOM });
}
function appendMessage() {
    count++;
    $.messages.appendRow({ title: 'New message ' + count, height: 72, color: '#111111', backgroundColor: '#eef2f7' });
}
function onTableLayout() {
    if (!initialized && $.messages.rect.height > 0) {
        initialized = true;
        $.messages.scrollToIndex(count - 1, { animated: false, position: Ti.UI.TableViewScrollPosition.BOTTOM });
        Ti.API.info('[ChatTest Alloy] table binding=' + ($.chat.keyboardScrollingView === $.messages) +
            ', extended=' + !!args.extended + ', edges=' + !!args.edges);
    }
}
function onClose() {
    $.chat.keyboardPanning = false;
    $.destroy();
}
