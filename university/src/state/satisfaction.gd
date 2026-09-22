class_name Satisfaction
## A satisfaction score and what it is made of: a base, less three penalties.

var base: float
var housing: float = 0.0
var crowding: float = 0.0
var unfed: float = 0.0


func total() -> float:
	return clampf(base - housing - crowding - unfed, 0.0, UniversityRules.MaxScore)
