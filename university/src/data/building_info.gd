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
# Academic seats, beds, and how many diners a dining hall is meant for.
var seats: int
var beds: int
var meals: int
# This type grants the price and minimum-grade levers: the Admissions Office.
var admissionsOffice: bool
# Seconds.
var buildTime: float
# Metres: the footprint's longest side (see Building.rectFor).
var diameter: float

## What a type is for, which decides its side-panel pane and how it is counted.
## A type with several capacities is the first that applies, in this order.
enum Role { Admissions, Academic, Housing, Dining, Other }


func _init(data: Dictionary) -> void:
	id = str(data["id"])
	name = str(data["name"])
	category = str(data.get("category", ""))
	cost = _dollars(data.get("costM", 0.0), DollarsPerM)
	upkeep = _dollars(data.get("upkeepK", 0.0), DollarsPerK)
	seats = maxi(Variants.toInt(data.get("seats", 0)), 0)
	beds = maxi(Variants.toInt(data.get("beds", 0)), 0)
	meals = maxi(Variants.toInt(data.get("meals", 0)), 0)
	admissionsOffice = Variants.toBool(data.get("admissionsOffice", false))
	buildTime = Variants.toFloat(data.get("buildTime", 0.0))
	diameter = Variants.toFloat(data.get("diameter", 0.0))


func role() -> Role:
	if (admissionsOffice):
		return Role.Admissions
	if (seats > 0):
		return Role.Academic
	if (beds > 0):
		return Role.Housing
	if (meals > 0):
		return Role.Dining
	return Role.Other


## What this type holds of its role: seats, beds or meals; 0 for the others.
func capacity() -> int:
	match role():
		Role.Academic:
			return seats
		Role.Housing:
			return beds
		Role.Dining:
			return meals
	return 0


# A Sheet money column, scaled and possibly fractional: non-negative, scaled
# by dollarsPerUnit, rounded to whole dollars.
static func _dollars(value: Variant, dollarsPerUnit: int) -> int:
	return roundi(maxf(Variants.toFloat(value), 0.0) * float(dollarsPerUnit))
