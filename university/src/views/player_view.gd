class_name PlayerView
extends Node2D


var player: Player


func _ready() -> void:
	pass


func _process(_dt: float) -> void:
	position = player.pos
	if Input.is_action_just_pressed("MoveRight"):
		player.vel.x += 1
	if Input.is_action_just_released("MoveRight"):
		player.vel.x -= 1
	if Input.is_action_just_pressed("MoveLeft"):
		player.vel.x += -1
	if Input.is_action_just_released("MoveLeft"):
		player.vel.x -= -1
	if Input.is_action_just_pressed("MoveDown"):
		player.vel.y += 1
	if Input.is_action_just_released("MoveDown"):
		player.vel.y -= 1
	if Input.is_action_just_pressed("MoveUp"):
		player.vel.y += -1
	if Input.is_action_just_released("MoveUp"):
		player.vel.y -= -1
