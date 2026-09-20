class_name StatusBar
extends Control

@onready var timeAmount: Label = %TimeAmount

var gameState: GameState

func _process(_dt: float) -> void:
	timeAmount.text = "%.2f s" % [gameState.gameTime]
