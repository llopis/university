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
	cost = roundi(maxf(Variants.toFloat(data.get("costM", 0.0)), 0.0) * float(DollarsPerM))
	upkeep = roundi(maxf(Variants.toFloat(data.get("upkeepK", 0.0)), 0.0) * float(DollarsPerK))
	buildTime = Variants.toFloat(data.get("buildTime", 0.0))
	diameter = Variants.toFloat(data.get("diameter", 0.0))
