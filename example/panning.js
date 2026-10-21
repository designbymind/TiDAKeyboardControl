// Focused panning test: no chat insets or automatic composer resizing.
module.exports = function () {
    require('it.smc.dakeyboardcontrol');

    var menu = Ti.UI.createWindow({
        title: 'Keyboard panning 1.1.1',
        backgroundColor: '#ffffff',
        extendSafeArea: false,
        layout: 'vertical'
    });
    var navigation = Ti.UI.createNavigationWindow({ window: menu });
    menu.add(Ti.UI.createLabel({
        text: 'Drag the blue margin to pan the keyboard. In TextArea modes, scroll inside the text: only the text should move.',
        top: 20, left: 16, right: 16, height: Ti.UI.SIZE, color: '#222222'
    }));

    function openTest(extended, allEdges, multiline) {
        var win = Ti.UI.createWindow({
            title: extended ? 'Extended content' : 'Safe-area content',
            backgroundColor: '#ffffff',
            extendSafeArea: extended,
            extendEdges: allEdges ? [Ti.UI.EXTEND_EDGE_ALL] : [],
            keyboardTriggerOffset: 80,
            keyboardPanning: true,
            orientationModes: [Ti.UI.PORTRAIT, Ti.UI.LANDSCAPE_LEFT, Ti.UI.LANDSCAPE_RIGHT]
        });
        var info = Ti.UI.createLabel({
            top: allEdges ? 110 : 20, left: 16, right: 16, height: Ti.UI.SIZE,
            color: '#222222',
            text: 'extendSafeArea: ' + extended + '\nextendEdges: ' + (allEdges ? 'ALL' : 'none') + '\n' + (multiline ? 'Scroll inside the TextArea; drag the blue margin to pan the keyboard.' : 'Blue bar should stay attached throughout a drag.')
        });
        var composer = Ti.UI.createView({
            left: 0, right: 0, bottom: 0, height: multiline ? 132 : 80, backgroundColor: '#007aff'
        });
        var input = multiline ? Ti.UI.createTextArea({
            left: 40, right: 80, height: 96, scrollable: true,
            value: 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8\nLine 9\nLine 10\nLine 11\nLine 12',
            backgroundColor: '#ffffff', color: '#111111', font: { fontSize: 18 }
        }) : Ti.UI.createTextField({
            left: 40, right: 80, height: 38, hintText: 'Tap to show keyboard',
            borderStyle: Ti.UI.INPUT_BORDERSTYLE_ROUNDED, backgroundColor: '#ffffff', color: '#111111'
        });
        var blur = Ti.UI.createButton({ right: 8, width: 64, height: 38, title: 'Hide', color: '#ffffff' });
        blur.addEventListener('click', function () { input.blur(); });
        composer.add(input);
        composer.add(blur);
        win.add(info);
        win.add(composer);
        var focus = Ti.UI.createButton({ title: 'Show keyboard', top: allEdges ? 240 : 150, height: 44 });
        focus.addEventListener('click', function () { Ti.API.info('[PanningTest] explicit focus requested'); input.focus(); });
        win.add(focus);
        input.addEventListener('focus', function () { Ti.API.info('[PanningTest] field focused'); });
        input.addEventListener('blur', function () { Ti.API.info('[PanningTest] field blurred'); });
        Ti.API.info('[PanningTest] enabled=' + win.keyboardPanning);
        win.lockedViews = [composer];
        var keyboardWasVisible = false;
        win.addEventListener('keyboardchange', function (event) {
            var valid = ['x', 'y', 'width', 'height'].every(function (key) {
                return typeof event[key] === 'number' && isFinite(event[key]);
            });
            if (!valid) Ti.API.error('[PanningTest] invalid keyboardchange frame');
            var visible = event.height > 0.5;
            if (visible !== keyboardWasVisible) {
                Ti.API.info('[PanningTest] keyboardchange ' + (visible ? 'visible' : 'hidden') + ', valid=' + valid);
                keyboardWasVisible = visible;
            }
        });
        composer.addEventListener('postlayout', function () {
            win.keyboardTriggerOffset = composer.rect.height;
        });
        var enable = Ti.UI.createButton({ title: 'Disable' });
        enable.addEventListener('click', function () {
            win.keyboardPanning = !win.keyboardPanning;
            enable.title = win.keyboardPanning ? 'Disable' : 'Enable';
        });
        win.rightNavButton = enable;
        win.addEventListener('close', function () { win.keyboardPanning = false; });
        navigation.openWindow(win);
    }

    var modes = [
        { title: 'Safe area / no extended edges', extended: false, edges: false },
        { title: 'Extended content / no extended edges', extended: true, edges: false },
        { title: 'Safe area / all extended edges', extended: false, edges: true },
        { title: 'Extended content / all extended edges', extended: true, edges: true }
    ];
    [false, true].forEach(function (multiline) {
        modes.forEach(function (mode) {
            var button = Ti.UI.createButton({ title: (multiline ? 'TextArea: ' : '') + mode.title, top: 8, left: 16, right: 16, height: 44 });
            button.addEventListener('click', function () { openTest(mode.extended, mode.edges, multiline); });
            menu.add(button);
        });
    });
    navigation.open();
};
