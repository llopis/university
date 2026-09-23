class_name KpiView
extends VBoxContainer
## One headline number and what it is, as in the mockup's dropdowns.

const ValueBase: String = "Value"

@onready var valueLabel: Label = %Value
@onready var captionLabel: Label = %Caption


func display(value: String, caption: String, tone: UiTone.Tone = UiTone.Tone.Normal) -> void:
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, tone)
	captionLabel.text = caption
