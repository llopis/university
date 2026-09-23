class_name SlotView
extends Button
## One top-bar slot: an icon, a number with a note beside it, and a caption.
## Pressing it opens its dropdown; it reads as pressed while that is open.

const ValueBase: String = "SlotValue"
const SubBase: String = "SlotSub"
# Left and right padding together, around the content.
const PaddingX: float = 36.0

@export var slotIcon: Texture2D

@onready var content: HBoxContainer = %Content
@onready var iconRect: TextureRect = %Icon
@onready var valueLabel: Label = %Value
@onready var subLabel: Label = %Sub
@onready var captionLabel: Label = %Caption
@onready var badge: Panel = %Badge


func _ready() -> void:
	iconRect.texture = slotIcon
	iconRect.self_modulate = get_theme_color("gold", "Palette")


func display(value: String, sub: String, caption: String, valueTone: UiTone.Tone, subTone: UiTone.Tone, warnBadge: bool) -> void:
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, valueTone)
	subLabel.text = sub
	subLabel.visible = (sub != "")
	subLabel.theme_type_variation = UiTone.variation(SubBase, subTone)
	captionLabel.text = caption
	badge.visible = warnBadge
	custom_minimum_size.x = content.get_combined_minimum_size().x + PaddingX
