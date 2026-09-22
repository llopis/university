class_name University
## The institution being run: its name and its campus. GameState holds one;
## everything the player runs hangs off it.

var name: String
var campus: Campus


func _init() -> void:
	campus = Campus.new()


## A new month began. The campus opens whatever is due.
func startMonth(newMonth: int) -> void:
	campus.startMonth(newMonth)
