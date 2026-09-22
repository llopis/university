class_name Problem
## Something wrong on campus right now, for alerts and campus markers. Every
## threshold lives in UniversityRules or Finances; this only carries what was
## found. count and fraction mean what the kind says.

enum Kind {
	HousingOverflow, # count: students off campus; fraction: their share
	DiningCrowded, # fraction: dining load, over 1
	DiningUnfed, # count: students who can't eat; fraction: dining load
	CreditMaxed, # count: the debt
}

var kind: Kind
var count: int
var fraction: float


func _init(problemKind: Kind, problemCount: int, problemFraction: float) -> void:
	kind = problemKind
	count = problemCount
	fraction = problemFraction
