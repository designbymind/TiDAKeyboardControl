// Compare real table scroll-edge appearance with keyboard panning off/on.
module.exports = function () {
    require('it.smc.dakeyboardcontrol');
    var menu = Ti.UI.createWindow({
        title: 'Navigation bar 1.1.1', backgroundColor: '#ffffff', layout: 'vertical'
    });
    var navigation = Ti.UI.createNavigationWindow({ window: menu });
    menu.add(Ti.UI.createLabel({
        top: 20, left: 16, right: 16, height: Ti.UI.SIZE, color: '#222222',
        text: 'Compare OFF and ON. Check the bar when opening, scrolling the table, returning to the top, and cancelling a back swipe.'
    }));

    function openTest(panning) {
        var win = Ti.UI.createWindow({
            title: 'Panning ' + (panning ? 'ON' : 'OFF'),
            backgroundColor: '#ffffff', extendSafeArea: true,
            extendEdges: [Ti.UI.EXTEND_EDGE_ALL], autoAdjustScrollViewInsets: true, keyboardPanning: panning
        });
        var rows = [];
        for (var i = 1; i <= 40; i++) {
            rows.push({ title: 'Message ' + i, height: 60, color: '#111111', backgroundColor: '#ffffff' });
        }
        var table = Ti.UI.createTableView({
            top: 0, bottom: 132, data: rows, backgroundColor: '#ffffff', scrollsToTop: true
        });
        win.add(table);
        var composer = Ti.UI.createView({
            bottom: 0, left: 0, right: 0, height: 132, backgroundColor: '#007aff'
        });
        var input = Ti.UI.createTextArea({
            left: 40, right: 80, height: 96, scrollable: true,
            value: 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8',
            backgroundColor: '#ffffff', color: '#111111', font: { fontSize: 18 }
        });
        var hide = Ti.UI.createButton({ title: 'Hide', right: 8, width: 64, height: 38, color: '#ffffff' });
        hide.addEventListener('click', function () { input.blur(); });
        composer.add(input);
        composer.add(hide);
        win.add(composer);
        win.lockedViews = [composer];
        composer.addEventListener('postlayout', function () { win.keyboardTriggerOffset = composer.rect.height; });
        var top = Ti.UI.createButton({ title: 'Top' });
        top.addEventListener('click', function () { table.scrollToIndex(0, { animated: false, position: Ti.UI.TableViewScrollPosition.TOP }); });
        win.rightNavButton = top;
        win.addEventListener('close', function () { win.keyboardPanning = false; });
        table.addEventListener('scroll', function (event) {
            if (event.contentOffset) Ti.API.info('[NavBarTest] panning=' + panning + ' tableY=' + event.contentOffset.y);
        });
        navigation.openWindow(win);
    }

    [false, true].forEach(function (panning) {
        var button = Ti.UI.createButton({ title: 'Keyboard panning ' + (panning ? 'ON' : 'OFF'), top: 20, height: 48 });
        button.addEventListener('click', function () { openTest(panning); });
        menu.add(button);
    });
    navigation.open();
};
