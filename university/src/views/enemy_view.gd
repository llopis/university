class_name EnemyView
extends Node2D

var enemy: Enemy


const ENEMY_VIEW = preload("uid://capry8s8mhenv")

static func create(_enemy: Enemy) -> EnemyView:
	var view: EnemyView = ENEMY_VIEW.instantiate()
	view.enemy = _enemy
	view.position = view.enemy.pos
	return view


func _ready() -> void:
	pass


func _process(_dt: float) -> void:
	position = enemy.pos
