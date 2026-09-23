class_name MoneyFormat
## How money reads in the UI: $10.0M, $950K, $0. The one place it is abbreviated.

const Million: int = 1000000
const Thousand: int = 1000
# Millions read to one decimal, so a tenth of a million is the smallest step
# shown. Everything is floored in whole dollars: an abbreviated balance must
# never read higher than the balance, or a price it cannot cover looks affordable.
const Tenths: int = 10
@warning_ignore("integer_division")
const MillionTenth: int = Million / Tenths


static func short(dollars: int) -> String:
	if (dollars >= Million):
		var tenthsOfMillion: int = floori(float(dollars) / float(MillionTenth))
		return "$%d.%dM" % [floori(float(tenthsOfMillion) / float(Tenths)), tenthsOfMillion % Tenths]
	if (dollars >= Thousand):
		return "$%dK" % floori(float(dollars) / float(Thousand))
	return "$%d" % dollars


## Whole dollars with thousands grouped: $9,606. For prices.
static func full(dollars: int) -> String:
	return (NumberFormat.Minus if (dollars < 0) else "") + "$" + NumberFormat.count(absi(dollars))


## Abbreviated with its direction: +$16.6M in, −$1.9M out, $0 for nothing.
static func signed(dollars: int) -> String:
	if (dollars == 0):
		return short(0)
	return ("+" if (dollars > 0) else NumberFormat.Minus) + short(absi(dollars))
