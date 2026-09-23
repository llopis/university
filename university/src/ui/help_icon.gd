class_name HelpIcon
extends TextureRect
## A (?) beside something that needs explaining: hovering it shows the
## explanation as a tooltip. The text is the node's tooltip_text, authored in
## the scene, or set by the owning view when it depends on numbers.

# Tooltips wrap at this width, so a long explanation reads as a paragraph.
const WrapWidth: float = 360.0
const TooltipStyle: StringName = &"Body"


func _ready() -> void:
	self_modulate = get_theme_color(&"muted", &"Palette")


func _make_custom_tooltip(forText: String) -> Object:
	var label: Label = Label.new()
	label.text = forText
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WrapWidth
	label.theme_type_variation = TooltipStyle
	return label
