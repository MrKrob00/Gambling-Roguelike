extends RefCounted
## The faceless croupier's voice. Lines live in i18n/strings.json as DEALER_<EVENT>_<1..N>.

const LINES_PER_EVENT := 3

static func line(event: StringName) -> String:
	var i := randi_range(1, LINES_PER_EVENT)
	return TranslationServer.translate("DEALER_%s_%d" % [String(event).to_upper(), i])
