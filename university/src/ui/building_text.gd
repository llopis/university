class_name BuildingText
## How a building type reads: what it holds ("400 seats"), what building one
## adds ("+400 seats") and its footprint ("40 × 24 m"). The one place these are
## worded, for the side panel, the build cards and the campus markers.

const HoldsSeats: String = "%s seats"
const HoldsBeds: String = "%s beds"
const HoldsMeals: String = "recommended for %s"
const HoldsAdmissions: String = "Admission and prices"
const AddsSeats: String = "+%s seats"
const AddsBeds: String = "+%s beds"
const AddsMeals: String = "+%s diners"
const FootprintFormat: String = "%d × %d m"
const UpkeepSuffix: String = " / mo"


static func holds(info: BuildingInfo) -> String:
	match info.role():
		BuildingInfo.Role.Academic:
			return HoldsSeats % NumberFormat.count(info.capacity())
		BuildingInfo.Role.Housing:
			return HoldsBeds % NumberFormat.count(info.capacity())
		BuildingInfo.Role.Dining:
			return HoldsMeals % NumberFormat.count(info.capacity())
		BuildingInfo.Role.Admissions:
			return HoldsAdmissions
	return ""


## What building one of these adds; empty for a type that adds no capacity.
static func adds(info: BuildingInfo) -> String:
	match info.role():
		BuildingInfo.Role.Academic:
			return AddsSeats % NumberFormat.count(info.capacity())
		BuildingInfo.Role.Housing:
			return AddsBeds % NumberFormat.count(info.capacity())
		BuildingInfo.Role.Dining:
			return AddsMeals % NumberFormat.count(info.capacity())
	return ""


## The footprint, long side by short, in whole metres: the box Building.rectFor places.
static func footprint(info: BuildingInfo) -> String:
	var box: Vector2 = Building.rectFor(info, Vector2.ZERO, 0.0).size
	return FootprintFormat % [roundi(box.x), roundi(box.y)]


## A type's upkeep as a monthly cost: −$2,400 / mo.
static func upkeep(info: BuildingInfo) -> String:
	return MoneyFormat.signed(-info.upkeep) + UpkeepSuffix
