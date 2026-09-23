class_name Stepper
extends HBoxContainer
## A labelled value with − and + beside it: an Admissions Office lever. It only
## announces a step; the owner of the value applies it and shows the result.

signal Stepped(direction: int)

const ValueBase: String = "StepValue"

@onready var captionLabel: Label = %Caption
@onready var downButton: Button = %Down
@onready var upButton: Button = %Up
@onready var valueLabel: Label = %Value


func _ready() -> void:
	downButton.pressed.connect(func() -> void: Stepped.emit(-1))
	upButton.pressed.connect(func() -> void: Stepped.emit(1))


func display(caption: String, value: String, dimmed: bool) -> void:
	captionLabel.text = caption
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, UiTone.Tone.Dim if (dimmed) else UiTone.Tone.Normal)
