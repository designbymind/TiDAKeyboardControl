function openChat(extended, edges, short) {
    var controller = Alloy.createController('chat', { extended: extended, edges: edges, short: short });
    $.navigation.openWindow(controller.getView());
}
function openSafe() { openChat(false, false, false); }
function openExtended() { openChat(true, false, false); }
function openSafeAll() { openChat(false, true, false); }
function openExtendedAll() { openChat(true, true, false); }
function openShort() { openChat(false, false, true); }
$.navigation.open();
