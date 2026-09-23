class_name UiTone
## The tone a number reads in: plain, good, a warning, bad, or dimmed. Each is a
## theme type variation: the base name plus a suffix, so ui_theme.tres decides
## the colour.

enum Tone { Normal, Good, Warn, Bad, Dim }

const Suffixes: Array[String] = ["", "Good", "Warn", "Bad", "Dim"]


static func variation(base: String, tone: Tone) -> StringName:
	return StringName(base + Suffixes[tone])
