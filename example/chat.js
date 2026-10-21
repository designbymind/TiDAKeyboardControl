// Isolated chat layout test. No networking or application-specific integration.
module.exports = function () {
    require('it.smc.dakeyboardcontrol');
    var menu = Ti.UI.createWindow({ title: 'Chat layout 1.2.1', backgroundColor: '#ffffff', layout: 'vertical' });
    var nav = Ti.UI.createNavigationWindow({ window: menu });
    menu.add(Ti.UI.createLabel({ top: 16, left: 16, right: 16, height: Ti.UI.SIZE, color: '#222222',
        text: 'Open a layout. Try the keyboard at the bottom and while reading history. Type multiple lines, scroll the TextArea, and pan from the blue margin.' }));

    function openChat(extended, edges, short) {
        var win = Ti.UI.createWindow({ title: short ? 'Short conversation' : 'Chat history', backgroundColor: '#ffffff',
            extendSafeArea: extended, extendEdges: edges ? [Ti.UI.EXTEND_EDGE_ALL] : [],
            autoAdjustScrollViewInsets: true, keyboardPanning: true });
        var count = short ? 2 : 45;
        var rows = [];
        for (var i = 1; i <= count; i++) rows.push({ title: 'Message ' + i + '\nA sample conversation message.', height: 72,
            color: '#111111', backgroundColor: i % 2 ? '#ffffff' : '#eef2f7', selectionStyle: Ti.UI.SELECTION_STYLE_NONE });
        var table = Ti.UI.createTableView({ top: 0, bottom: 0, data: rows, separatorStyle: Ti.UI.TABLE_VIEW_SEPARATOR_STYLE_NONE });
        win.add(table);
        var bar = Ti.UI.createView({ left: 0, right: 0, bottom: 0, height: 80, backgroundColor: '#007aff' });
        var input = Ti.UI.createTextArea({ left: 36, right: 76, top: 12, height: 42, scrollable: true,
            font: { fontSize: 17 }, color: '#111111', backgroundColor: '#ffffff',
            padding: { top: 8, bottom: 8, left: 8, right: 8 }, suppressReturn: false });
        input.addEventListener('change', function (event) {
            var height = Math.max(42, Math.min(160, event.contentHeight || 42));
            input.height = height;
            bar.height = height + 38;
        });
        var hide = Ti.UI.createButton({ title: 'Hide', right: 6, top: 12, width: 64, height: 42, color: '#ffffff' });
        hide.addEventListener('click', function () { input.blur(); });
        bar.add(input); bar.add(hide); win.add(bar);
        win.lockedViews = [bar];
        win.keyboardScrollingView = table;
        win.keyboardDismissalScrollCorrection = true; // Set false to compare uncorrected dismissal.
        win.keyboardScrollToBottomThreshold = 60; // Points; tune here, or use 0 to disable refocus snapping.
        bar.addEventListener('postlayout', function () { win.keyboardTriggerOffset = bar.rect.height; });
        var latest = Ti.UI.createButton({ title: 'Latest' });
        latest.addEventListener('click', function () { table.scrollToIndex(count - 1, { animated: true, position: Ti.UI.TableViewScrollPosition.BOTTOM }); });
        var append = Ti.UI.createButton({ title: 'Append' });
        append.addEventListener('click', function () {
            count++;
            table.appendRow({ title: 'New message ' + count, height: 72, color: '#111111', backgroundColor: '#eef2f7' });
        });
        win.rightNavButtons = [latest, append];
        var initialized = false;
        table.addEventListener('postlayout', function () {
            if (!initialized && table.rect.height > 0) {
                initialized = true;
                table.scrollToIndex(count - 1, { animated: false, position: Ti.UI.TableViewScrollPosition.BOTTOM });
                Ti.API.info('[ChatTest] table binding=' + (win.keyboardScrollingView === table) + ', extended=' + extended + ', edges=' + edges);
            }
        });
        win.addEventListener('close', function () { win.keyboardPanning = false; });
        nav.openWindow(win);
    }
    [
        { title: 'Safe area / no extended edges', extended: false, edges: false },
        { title: 'Extended / no extended edges', extended: true, edges: false },
        { title: 'Safe area / all edges', extended: false, edges: true },
        { title: 'Extended / all edges', extended: true, edges: true },
        { title: 'Short conversation', extended: false, edges: false, short: true }
    ].forEach(function (mode) {
        var button = Ti.UI.createButton({ title: mode.title, top: 16, height: 48 });
        button.addEventListener('click', function () { openChat(mode.extended, mode.edges, mode.short); });
        menu.add(button);
    });
    nav.open();
};
