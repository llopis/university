class_name InfoRow
extends HBoxContainer
## A key, its value and a note: the mockup's .row. The value takes a tone; a
## pill can flag it.

const ValueBase: String = "Body"
const PillBase: String = "Pill"

@onready var keyLabel: Label = %Key
@onready var valueLabel: Label = %Value
@onready var noteLabel: Label = %Note
@onready var pill: Label = %Pill


func display(key: String, value: String, note: String = "", tone: UiTone.Tone = UiTone.Tone.Normal) -> void:
	keyLabel.text = key
	valueLabel.text = value
	valueLabel.theme_type_variation = UiTone.variation(ValueBase, tone)
	noteLabel.text = note
	noteLabel.visible = (note != "")


## A pill beside the value; empty text hides it.
func showPill(text: String, tone: UiTone.Tone) -> void:
	pill.visible = (text != "")
	pill.text = text
	pill.theme_type_variation = UiTone.variation(PillBase, tone)
