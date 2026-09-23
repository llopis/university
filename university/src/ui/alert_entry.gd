class_name AlertEntry
## One line in the alerts list: a problem that holds now, or an event.

enum Source { Problem, AutoBorrowed, Opened }

var source: Source
# The problem, for Source.Problem; refreshed every update while it holds.
var problem: Problem
# The shortfall and its fee, for Source.AutoBorrowed.
var amount: int = 0
var fee: int = 0
# The building that opened, for Source.Opened.
var building: Building
# Weeks since the game began, when it first showed.
var week: int = 0


func _init(entrySource: Source, atWeek: int) -> void:
	source = entrySource
	week = atWeek
