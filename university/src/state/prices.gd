class_name Prices
## What a semester costs a student, in whole dollars: tuition, a room on
## campus and a meal plan. Off-campus students pay tuition only.

# Keys toDict writes; fromDict refuses a dictionary missing any of them.
const SavedKeys: Array[String] = ["tuition", "room", "mealPlan"]

var tuition: int
var room: int
var mealPlan: int


func _init(tuitionPrice: int, roomPrice: int, mealPlanPrice: int) -> void:
	tuition = tuitionPrice
	room = roomPrice
	mealPlan = mealPlanPrice


## The sticker price applicants weigh: everything a semester on campus costs.
func total() -> int:
	return tuition + room + mealPlan


func copy() -> Prices:
	return Prices.new(tuition, room, mealPlan)


func toDict() -> Dictionary:
	return {"tuition": tuition, "room": room, "mealPlan": mealPlan}


## Null when data is missing a key. A price below zero reads as zero.
static func fromDict(data: Dictionary) -> Prices:
	if (not Variants.hasKeys(data, SavedKeys, "Prices")):
		return null
	return Prices.new(
		maxi(Variants.toInt(data["tuition"]), 0),
		maxi(Variants.toInt(data["room"]), 0),
		maxi(Variants.toInt(data["mealPlan"]), 0))
