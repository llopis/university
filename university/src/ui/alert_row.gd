class_name AlertRow
extends PanelContainer
## One alert line: when it appeared, what it says, and ×. Clicking the line
## asks for its place; × asks to dismiss it.

signal Activated
signal Dismissed

const WeekFormat: String = "wk %d"
const AccentBase: String = "AlertAccent"
const AccentWarn: String = "Warn"
const AccentBad: String = "Bad"
const AccentInfo: String = "Info"

@onready var whenLabel: Label = %When
@onready var textLabel: Label = %Text
@onready var closeButton: Button = %Close
@onready var accent: Panel = %Accent

var entry: AlertEntry


func _ready() -> void:
	closeButton.pressed.connect(func() -> void: Dismissed.emit())
	gui_input.connect(_onGuiInput)


## accentName is "Warn", "Bad" or "Info".
func display(text: String, week: int, accentName: String) -> void:
	textLabel.text = text
	whenLabel.text = WeekFormat % GameCalendar.weekInPeriod(week)
	accent.theme_type_variation = StringName(AccentBase + accentName)


func _onGuiInput(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		Activated.emit()
		accept_event()


## The accent a problem reads in, wherever one is shown: an alert, a marker.
static func accentFor(kind: Problem.Kind) -> String:
	match kind:
		Problem.Kind.HousingOverflow:
			return AccentBad
		Problem.Kind.DiningCrowded:
			return AccentWarn
		Problem.Kind.DiningUnfed:
			return AccentBad
		Problem.Kind.CreditMaxed:
			return AccentBad
	return AccentBad
