class_name SlotView
extends Button
## One top-bar slot: an icon and a number with a note beside it, named by its
## tooltip. Pressing it opens its dropdown; it reads as pressed while that is open.

const ValueBase: String = "Heading"
const SubBase: String = "Caption"
# Left and right padding together, around the content.
const PaddingX: float = 36.0

@export var slotIcon: Texture2D

@onready var content: HBoxContainer = %Content
@onready var iconRect: TextureRect = %Icon
@onready var valueLabel: Label = %Value
@onready var subLabel: Label = %Sub


func _ready() -> void:
	iconRect.texture = slotIcon
	iconRect.self_modulate = get_theme_color("accent", "Palette")


func display(value: String, sub: String, tooltip: String, valueTone: UiTone.Tone, subTone: UiTone.Tone) -> void:
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, valueTone)
	subLabel.text = sub
	subLabel.visible = (sub != "")
	subLabel.theme_type_variation = UiTone.variation(SubBase, subTone)
	tooltip_text = tooltip
	custom_minimum_size.x = content.get_combined_minimum_size().x + PaddingX
