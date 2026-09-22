class_name BuildingInfo
## One building type's definition, parsed from a row of the Buildings tab
## (values arrive as Variant via CsvLoader). The Sheet is the source of truth —
## see CLAUDE.md's Data section.

# The Sheet authors cost in millions of dollars (the `costM` column, which may
# be fractional); it is held in whole dollars, converted here and nowhere else.
const DollarsPerM: int = 1000000

# The Sheet authors upkeep in thousands of dollars a month (the `upkeepK`
# column, which may be fractional); it is held in whole dollars, converted here
# and nowhere else.
const DollarsPerK: int = 1000

var id: String
var name: String
var category: String
# Whole dollars.
var cost: int
# Whole dollars a month, while the building is open.
var upkeep: int
# Seconds.
var buildTime: float
# Metres: the footprint's longest side (see Building.rectFor).
var diameter: float


func _init(data: Dictionary) -> void:
	id = str(data["id"])
	name = str(data["name"])
	category = str(data.get("category", ""))
	cost = _dollars(data.get("costM", 0.0), DollarsPerM)
	upkeep = _dollars(data.get("upkeepK", 0.0), DollarsPerK)
	buildTime = Variants.toFloat(data.get("buildTime", 0.0))
	diameter = Variants.toFloat(data.get("diameter", 0.0))


# A Sheet money column, scaled and possibly fractional: non-negative, scaled
# by dollarsPerUnit, rounded to whole dollars.
static func _dollars(value: Variant, dollarsPerUnit: int) -> int:
	return roundi(maxf(Variants.toFloat(value), 0.0) * float(dollarsPerUnit))
