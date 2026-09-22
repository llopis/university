class_name Fees
## One semester start's fees, whole dollars, by what they pay for.

var tuition: int = 0
var room: int = 0
var meals: int = 0


func total() -> int:
	return tuition + room + meals
