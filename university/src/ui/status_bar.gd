class_name StatusBar
extends Control
## The top strip: the transport controls, the date and the money. It owns no
## state: the buttons call the game state, and what they show is polled every
## frame because speed and pause also change from keys and the console.

@onready var pauseButton: Button = %PauseButton
@onready var playButton: Button = %PlayButton
@onready var fastButton: Button = %FastButton
@onready var fasterButton: Button = %FasterButton
@onready var dateLabel: Label = %DateLabel
@onready var moneyAmount: Label = %MoneyAmount

var gameState: GameState

# The transport buttons in speed order: index i runs GameState.SpeedSteps[i].
var _speedButtons: Array[Button]


func _ready() -> void:
	_speedButtons = [playButton, fastButton, fasterButton]
	pauseButton.pressed.connect(_onPausePressed)
	for i: int in range(_speedButtons.size()):
		_speedButtons[i].pressed.connect(_onSpeedPressed.bind(i))


func _process(_dt: float) -> void:
	dateLabel.text = GameCalendar.label(gameState.month())
	moneyAmount.text = MoneyFormat.short(gameState.campus.money)
	# Exactly one transport button reads as pressed.
	pauseButton.set_pressed_no_signal(gameState.paused)
	for i: int in range(_speedButtons.size()):
		_speedButtons[i].set_pressed_no_signal(not gameState.paused and gameState.speedIndex == i)


func _onPausePressed() -> void:
	gameState.paused = true


func _onSpeedPressed(index: int) -> void:
	gameState.paused = false
	gameState.setSpeedIndex(index)
