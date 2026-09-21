class_name BuildingInfo
## One building type's definition, parsed from a row of the Buildings tab
## (values arrive as Variant via CsvLoader). The Sheet is the source of truth —
## see CLAUDE.md's Data section.

# The Sheet authors cost in thousands of dollars; it is held in whole dollars,
# converted here and nowhere else.
const DollarsPerK: int = 1000

var id: String
var name: String
var category: String
# Whole dollars.
var cost: int
# Seconds.
var buildTime: float
# Metres: the footprint's longest side (see Building.rectFor).
var diameter: float


func _init(data: Dictionary) -> void:
	id = str(data["id"])
	name = str(data["name"])
	category = str(data.get("category", ""))
	cost = maxi(_toInt(data.get("cost", 0)), 0) * DollarsPerK
	buildTime = _toFloat(data.get("buildTime", 0.0))
	diameter = _toFloat(data.get("diameter", 0.0))


# A blank cell arrives as "", so anything that is not a number reads as zero.
static func _toInt(value: Variant) -> int:
	if (value is int):
		return value
	if (value is float):
		return int(value as float)
	return 0


static func _toFloat(value: Variant) -> float:
	if (value is float):
		return value
	if (value is int):
		return float(value as int)
	return 0.0
