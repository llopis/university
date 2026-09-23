class_name AlertFeed
## Which alerts show. Plain data, so its rules are tested without the engine:
## - a problem shows while it holds, dated the week it first appeared;
## - dismissing a problem hides it until it clears, and it comes back, newly
##   dated, if it returns;
## - events show newest first, at most MaxEvents, until dismissed;
## - problems come before events.

const MaxEvents: int = 5

var _problems: Array[AlertEntry] = []
var _events: Array[AlertEntry] = []
# Problem kinds dismissed while they still hold; each is forgotten when its
# problem clears.
var _dismissed: Array[int] = []


## Brings the problem lines up to date with what is wrong now.
func update(current: Array[Problem], week: int) -> void:
	var kept: Array[AlertEntry] = []
	var present: Array[int] = []
	for problem: Problem in current:
		present.append(problem.kind)
		var entry: AlertEntry = _problemEntry(problem.kind)
		if (entry == null):
			entry = AlertEntry.new(AlertEntry.Source.Problem, week)
		entry.problem = problem
		kept.append(entry)
	_problems = kept
	var stillDismissed: Array[int] = []
	for kind: int in _dismissed:
		if (present.has(kind)):
			stillDismissed.append(kind)
	_dismissed = stillDismissed


## A new event, shown first; the oldest beyond MaxEvents drops off.
func addEvent(entry: AlertEntry) -> void:
	_events.push_front(entry)
	if (_events.size() > MaxEvents):
		_events.resize(MaxEvents)


func dismiss(entry: AlertEntry) -> void:
	if (entry.source == AlertEntry.Source.Problem):
		if (not _dismissed.has(entry.problem.kind)):
			_dismissed.append(entry.problem.kind)
	else:
		_events.erase(entry)


## What shows now: the problems not dismissed, in problems() order, then the
## events, newest first.
func shown() -> Array[AlertEntry]:
	var lines: Array[AlertEntry] = []
	for entry: AlertEntry in _problems:
		if (not _dismissed.has(entry.problem.kind)):
			lines.append(entry)
	lines.append_array(_events)
	return lines


func _problemEntry(kind: Problem.Kind) -> AlertEntry:
	for entry: AlertEntry in _problems:
		if (entry.problem.kind == kind):
			return entry
	return null
