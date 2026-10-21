var automatic = require('automatic');
var manual = require('manual');
var panning = require('panning');
var chat = require('chat');

var win = Ti.UI.createWindow({
	layout:'vertical'
});

var automaticButton = Ti.UI.createButton({
	title: 'Automatic',
	width: 150,
	height: 50
});

var manualButton = Ti.UI.createButton({
	title: 'Manual',
	width: 150,
	height: 50
});

var panningButton = Ti.UI.createButton({
	title: 'Modern panning',
	width: 200,
	height: 50
});

automaticButton.addEventListener('click', automatic);
manualButton.addEventListener('click', manual);
panningButton.addEventListener('click', panning);

win.add(automaticButton);
win.add(manualButton);
win.add(panningButton);
var chatButton = Ti.UI.createButton({ title: 'Chat layout', width: 200, height: 50 });
chatButton.addEventListener('click', chat);
win.add(chatButton);

win.open();
