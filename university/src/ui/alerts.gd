class_name Alerts
extends VBoxContainer
## Alerts stacked top-right, under the bar: a line for every problem that
## holds now, and for events (an automatic loan, a building opening).
## Clicking a line asks for its place; × dismisses it, following AlertFeed's
## rules.

signal PlaceWanted(entry: AlertEntry)

const RowScene: PackedScene = preload("res://src/ui/alert_row.tscn")

const HousingOverflowFormat: String = "%s students without on-campus housing (%s)"
const DiningCrowdedFormat: String = "Dining at %s of its recommended load: crowded"
const DiningUnfedFormat: String = "%s students can't eat"
const CreditMaxedText: String = "Credit line used up"
const AutoBorrowedFormat: String = "Monthly bill short by %s: borrowed automatically (+%s fee)"
const OpenedFormat: String = "%s opened"

const AccentWarn: String = "Warn"
const AccentBad: String = "Bad"
const AccentInfo: String = "Info"

var feed: AlertFeed = AlertFeed.new()
var state: GameState
var _rows: Array[AlertRow]


func setup(gameState: GameState) -> void:
	state = gameState
	state.university.finances.AutoBorrowed.connect(_onAutoBorrowed)
	state.university.campus.BuildingOpened.connect(_onBuildingOpened)


func _process(_dt: float) -> void:
	if (state == null):
		return
	feed.update(state.university.problems(), state.week())
	var lines: Array[AlertEntry] = feed.shown()
	if (_changed(lines)):
		_rebuild(lines)
	for i: int in _rows.size():
		var entry: AlertEntry = lines[i]
		_rows[i].display(_textFor(entry), entry.week, _accentFor(entry))


# Fires mid-tick (Finances.charge), so this only adds to the feed.
func _onAutoBorrowed(shortfall: int, fee: int) -> void:
	var entry: AlertEntry = AlertEntry.new(AlertEntry.Source.AutoBorrowed, state.week())
	entry.amount = shortfall
	entry.fee = fee
	feed.addEvent(entry)


# Fires mid-tick (Campus.startMonth), so this only adds to the feed.
func _onBuildingOpened(building: Building) -> void:
	var entry: AlertEntry = AlertEntry.new(AlertEntry.Source.Opened, state.week())
	entry.building = building
	feed.addEvent(entry)


func _changed(lines: Array[AlertEntry]) -> bool:
	if (lines.size() != _rows.size()):
		return true
	for i: int in lines.size():
		if (_rows[i].entry != lines[i]):
			return true
	return false


func _rebuild(lines: Array[AlertEntry]) -> void:
	for row: AlertRow in _rows:
		remove_child(row)
		row.queue_free()
	_rows.clear()
	for entry: AlertEntry in lines:
		var row: AlertRow = RowScene.instantiate()
		add_child(row)
		row.entry = entry
		row.Activated.connect(func() -> void: PlaceWanted.emit(entry))
		row.Dismissed.connect(func() -> void: feed.dismiss(entry))
		_rows.append(row)


func _textFor(entry: AlertEntry) -> String:
	match entry.source:
		AlertEntry.Source.Problem:
			return _problemText(entry.problem)
		AlertEntry.Source.AutoBorrowed:
			return AutoBorrowedFormat % [MoneyFormat.short(entry.amount), MoneyFormat.short(entry.fee)]
		AlertEntry.Source.Opened:
			return OpenedFormat % entry.building.info.name
	return ""


func _problemText(problem: Problem) -> String:
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


func _accentFor(entry: AlertEntry) -> String:
	match entry.source:
		AlertEntry.Source.Problem:
			return _problemAccent(entry.problem.kind)
		AlertEntry.Source.AutoBorrowed:
			return AccentWarn
		AlertEntry.Source.Opened:
			return AccentInfo
	return AccentInfo


func _problemAccent(kind: Problem.Kind) -> String:
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
