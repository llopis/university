class_name MoneyFormat
## How money reads in the UI: $10.0M, $950K, $0. The one place it is abbreviated.

const Million: int = 1000000
const Thousand: int = 1000


static func short(dollars: int) -> String:
	if (dollars >= Million):
		return "$%.1fM" % (float(dollars) / float(Million))
	if (dollars >= Thousand):
		return "$%dK" % roundi(float(dollars) / float(Thousand))
	return "$%d" % dollars
