class_name UiTone
## The tone a number reads in: plain, good, a warning, bad, or dimmed. Each is a
## theme type variation: the base name plus a suffix, so ui_theme.tres decides
## the colour.

enum Tone { Normal, Good, Warn, Bad, Dim }

const Suffixes: Array[String] = ["", "Good", "Warn", "Bad", "Dim"]
# How close to a target reads as "held" rather than trending toward it.
const HeldWithin: float = 0.5


static func variation(base: String, tone: Tone) -> StringName:
	return StringName(base + Suffixes[tone])


## Whether a value is trending toward a target: Good when the target is more
## than HeldWithin above it, Bad when it is more than HeldWithin below, Normal
## otherwise.
static func trend(value: float, target: float) -> Tone:
	if (target > value + HeldWithin):
		return Tone.Good
	if (target < value - HeldWithin):
		return Tone.Bad
	return Tone.Normal
