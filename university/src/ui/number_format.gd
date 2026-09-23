class_name NumberFormat
## How counts and shares read in the UI: 1,080 and 33%. The one place digits
## are grouped.

const GroupSize: int = 3
# "Separator" shadows a native Godot class (the base of HSeparator/VSeparator).
const GroupSeparator: String = ","
# A real minus sign, not a hyphen.
const Minus: String = "−"
const Hundred: float = 100.0
# Floating-point slack, so 0.29 floors to 29% and not 28%.
const FloorSlack: float = 0.000001


static func count(n: int) -> String:
	var digits: String = str(absi(n))
	var grouped: String = ""
	while (digits.length() > GroupSize):
		grouped = GroupSeparator + digits.substr(digits.length() - GroupSize) + grouped
		digits = digits.substr(0, digits.length() - GroupSize)
	return (Minus if (n < 0) else "") + digits + grouped


## A fraction as a whole percentage, floored so a share never reads higher than it is.
static func percent(fraction: float) -> String:
	return "%d%%" % floori(fraction * Hundred + FloorSlack)
