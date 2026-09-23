class_name GameMenu
extends PanelContainer
## The game itself, apart from the university: save, load, start over, quit.

signal Chosen

@onready var saveButton: Button = %SaveButton
@onready var loadButton: Button = %LoadButton
@onready var newGameButton: Button = %NewGameButton
@onready var quitButton: Button = %QuitButton


func _ready() -> void:
	saveButton.pressed.connect(func() -> void: _choose(func() -> void: Global.saveGame(Global.QuickSavePath)))
	loadButton.pressed.connect(func() -> void: _choose(func() -> void: Global.loadGame(Global.QuickSavePath)))
	newGameButton.pressed.connect(func() -> void: _choose(func() -> void: Global.newGame()))
	quitButton.pressed.connect(func() -> void: get_tree().quit())


func _process(_dt: float) -> void:
	if (visible):
		loadButton.disabled = not SaveFile.exists(Global.QuickSavePath)


func _choose(action: Callable) -> void:
	Chosen.emit()
	action.call()
