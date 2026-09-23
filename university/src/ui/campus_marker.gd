class_name CampusMarker
extends VBoxContainer
## One label over the campus: an accented box with two lines of text and a
## stem pointing down at the ground point it is anchored to. Clicking it asks
## for its place, mirroring AlertRow.

signal Activated

@onready var box: PanelContainer = %Box
@onready var accent: Panel = %Accent
@onready var textLabel: Label = %Text
@onready var smallLabel: Label = %Small

# What Activated stands for right now: a building going up, or else a problem.
var problemKind: Problem.Kind
var building: Building


func _ready() -> void:
	box.gui_input.connect(_onGuiInput)


## accentName is "Warn", "Bad" or "Info".
func display(text: String, small: String, accentName: String) -> void:
	textLabel.text = text
	smallLabel.text = small
	accent.theme_type_variation = StringName(AlertRow.AccentBase + accentName)


## Sets position so the stem's foot sits on point (viewport/design-space coordinates).
func anchorAt(point: Vector2) -> void:
	position = point - Vector2(size.x / 2.0, size.y)


func _onGuiInput(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		Activated.emit()
		accept_event()
