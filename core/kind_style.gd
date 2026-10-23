extends RefCounted
## One colour per artifact kind, used everywhere an artifact is drawn (token, offer, info panel, collection),
## so the kind can be read at a glance. Order matches ArtifactData.Kind: ACTIVE, PASSIVE, CONSUMABLE, CURSED.

const COLORS: Array[Color] = [
	Color(0.36, 0.76, 0.96),  # active: cold blue, you press it
	Color(0.46, 0.86, 0.5),   # passive: green, always on
	Color(0.96, 0.66, 0.24),  # consumable: amber, burns away
	Color(0.92, 0.28, 0.42),  # cursed: crimson, a price attached
]
const KIND_KEYS: Array[String] = ["KIND_ACTIVE", "KIND_PASSIVE", "KIND_CONSUMABLE", "KIND_CURSED"]
const BENEFIT := Color(0.5, 0.88, 0.55)
const COST := Color(0.94, 0.4, 0.36)
const NEUTRAL := Color(0.82, 0.82, 0.92)

static func color_of(kind: int) -> Color:
	return COLORS[kind]

static func hex_of(kind: int) -> String:
	return COLORS[kind].to_html(false)

## "+ line" is a benefit, "- line" is a cost, anything else is plain. Returns BBCode.
static func describe_bbcode(description: String) -> String:
	var out: PackedStringArray = []
	for line in description.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("+"):
			out.append("[color=#%s]%s[/color]" % [BENEFIT.to_html(false), t])
		elif t.begins_with("-"):
			out.append("[color=#%s]%s[/color]" % [COST.to_html(false), t])
		else:
			out.append("[color=#%s]%s[/color]" % [NEUTRAL.to_html(false), t])
	return "\n".join(out)
