class_name ClickAway
extends Control
## A surface that closes whatever it sits behind when clicked: an overlay's
## dim. It only reports the press; its owner decides what closing means.

signal Clicked


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		Clicked.emit()
		accept_event()
