class_name SlotView
extends Button
## One top-bar slot: an icon, a number with a note beside it, and a caption.
## Pressing it opens its dropdown; it reads as pressed while that is open.

const ValueBase: String = "Value"
const SubBase: String = "Caption"
# Left and right padding together, around the content.
const PaddingX: float = 36.0

@export var slotIcon: Texture2D

@onready var content: HBoxContainer = %Content
@onready var iconRect: TextureRect = %Icon
@onready var valueLabel: Label = %Value
@onready var subLabel: Label = %Sub
@onready var captionLabel: Label = %Caption


func _ready() -> void:
	iconRect.texture = slotIcon
	iconRect.self_modulate = get_theme_color("accent", "Palette")


func display(value: String, sub: String, caption: String, valueTone: UiTone.Tone, subTone: UiTone.Tone) -> void:
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, valueTone)
	subLabel.text = sub
	subLabel.visible = (sub != "")
	subLabel.theme_type_variation = UiTone.variation(SubBase, subTone)
	captionLabel.text = caption
	custom_minimum_size.x = content.get_combined_minimum_size().x + PaddingX
