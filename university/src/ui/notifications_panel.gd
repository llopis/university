class_name NotificationsPanel
extends PanelContainer
## The popover under the bell: one row per problem holding now, in
## University.problems() order, with no dates and no dismiss. A row's press
## asks for its place. Rows are built in code because how many there are is
## live; rebuilt only when the set of kinds changes, their text refreshed
## every frame.

signal ProblemWanted(kind: Problem.Kind)

const HousingOverflowFormat: String = "%s students without on-campus housing (%s)"
const DiningCrowdedFormat: String = "Dining at %s of its recommended load: crowded"
const DiningUnfedFormat: String = "%s students can't eat"
const CreditMaxedText: String = "Credit line used up"

# A row's StatusDot, positioned the way university_menu.tscn's dots are:
# vertically centred inside MenuItemDotted's reserved left margin.
const DotSize: float = 8.0
const DotMarginLeft: float = 8.0

@onready var rows: VBoxContainer = %Rows
@onready var emptyNote: Label = %EmptyNote

var university: University

var _kinds: Array[Problem.Kind] = []
var _rowButtons: Array[Button] = []


func _process(_dt: float) -> void:
	if (not visible or university == null):
		return
	var problems: Array[Problem] = university.problems()
	rows.visible = not problems.is_empty()
	emptyNote.visible = problems.is_empty()
	if (_changed(problems)):
		_rebuild(problems)
	for i: int in problems.size():
		_rowButtons[i].text = _textFor(problems[i])


func _changed(problems: Array[Problem]) -> bool:
	if (problems.size() != _kinds.size()):
		return true
	for i: int in problems.size():
		if (problems[i].kind != _kinds[i]):
			return true
	return false


func _rebuild(problems: Array[Problem]) -> void:
	for row: Button in _rowButtons:
		rows.remove_child(row)
		row.queue_free()
	_rowButtons.clear()
	_kinds.clear()
	for problem: Problem in problems:
		var row: Button = _buildRow(problem)
		rows.add_child(row)
		_rowButtons.append(row)
		_kinds.append(problem.kind)


func _buildRow(problem: Problem) -> Button:
	var row: Button = Button.new()
	row.theme_type_variation = &"MenuItemDotted"
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var kind: Problem.Kind = problem.kind
	row.pressed.connect(func() -> void: ProblemWanted.emit(kind))

	var dot: Panel = Panel.new()
	dot.theme_type_variation = &"StatusDot"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = DotMarginLeft
	dot.offset_right = DotMarginLeft + DotSize
	dot.offset_top = -DotSize / 2.0
	dot.offset_bottom = DotSize / 2.0
	dot.self_modulate = get_theme_color(_dotColor(kind), &"Palette")
	row.add_child(dot)

	return row


func _textFor(problem: Problem) -> String:
	match problem.kind:
		Problem.Kind.HousingOverflow:
			return HousingOverflowFormat % [NumberFormat.count(problem.count), NumberFormat.percent(problem.fraction)]
		Problem.Kind.DiningCrowded:
			return DiningCrowdedFormat % NumberFormat.percent(problem.fraction)
		Problem.Kind.DiningUnfed:
			return DiningUnfedFormat % NumberFormat.count(problem.count)
		Problem.Kind.CreditMaxed:
			return CreditMaxedText
	return ""


func _dotColor(kind: Problem.Kind) -> StringName:
	return &"warn" if (kind == Problem.Kind.HousingOverflow or kind == Problem.Kind.DiningCrowded) else &"bad"
