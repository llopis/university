class_name Variants
## Reads typed values out of parsed data. JSON has one number type, so a saved
## int comes back as a float; a blank CSV cell comes back as "". The one place
## either becomes an int, a float or a bool.


## A float reads truncated toward zero, which gives back exactly every whole
## number JSON wrote. Anything that is not a number reads as zero.
static func toInt(value: Variant) -> int:
	if (value is int):
		return value
	if (value is float):
		return int(value as float)
	return 0


## Anything that is not a number reads as zero.
static func toFloat(value: Variant) -> float:
	if (value is float):
		return value
	if (value is int):
		return float(value as int)
	return 0.0


## Anything that is not a bool reads as false.
static func toBool(value: Variant) -> bool:
	if (value is bool):
		return value
	return false
