extends SceneTree
## Builds res://ui/theme.tres from the Dark Dwellers sprites.
## Run: godot --headless --path . --script res://tools/build_theme.gd

const DD := "res://assets/ui/dark_dwellers/"
const BODY_FONT := "res://assets/fonts/metamorphous/Metamorphous-Regular.ttf"
const BODY_FALLBACK := "res://assets/fonts/kurale/Kurale-Regular.ttf"
const TITLE_FONT := "res://assets/fonts/pirata_one/PirataOne-Regular.ttf"
const TITLE_FALLBACK := "res://assets/fonts/cormorant_unicase/CormorantUnicase-Bold.ttf"

const TEXT := Color("d9d4f0")
const TEXT_HOVER := Color("f4a13a")
const TEXT_DISABLED := Color("6b699b")

func _frame(sheet: Texture2D, region: Rect2, margin: Vector4, content: Vector4) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	var box := StyleBoxTexture.new()
	box.texture = atlas
	box.texture_margin_left = margin.x
	box.texture_margin_top = margin.y
	box.texture_margin_right = margin.z
	box.texture_margin_bottom = margin.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box

## The Latin font leads; the fallback covers Cyrillic, which neither gothic face has.
func _font(base_path: String, fallback_path: String) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = load(base_path)
	v.fallbacks = [load(fallback_path)]
	return v

func _init() -> void:
	var theme := Theme.new()
	var title := _font(TITLE_FONT, TITLE_FALLBACK)
	print("title font saved: ", error_string(ResourceSaver.save(title, "res://ui/fonts/title_font.tres")))
	var body := _font(BODY_FONT, BODY_FALLBACK)
	print("body font saved: ", error_string(ResourceSaver.save(body, "res://ui/fonts/body_font.tres")))
	theme.default_font = load("res://ui/fonts/body_font.tres")
	theme.default_font_size = 12

	var buttons: Texture2D = load(DD + "20251029darkDwellersButtonC1-Sheet.png")
	var states := {"normal": 0, "hover": 1, "pressed": 2, "disabled": 3}
	for state in states:
		var region := Rect2(states[state] * 96, 0, 96, 24)
		theme.set_stylebox(state, "Button", _frame(buttons, region, Vector4(18, 6, 18, 6), Vector4(20, 3, 20, 3)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT_HOVER)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	var slots: Texture2D = load(DD + "20251124emptyFrameA1-Sheet.png")
	theme.set_type_variation(&"TileButton", &"Button")
	var tile_states := {"normal": 0, "hover": 1, "pressed": 2, "disabled": 4}
	for state in tile_states:
		var region := Rect2(tile_states[state] * 32, 0, 32, 32)
		theme.set_stylebox(state, "TileButton", _frame(slots, region, Vector4(6, 6, 6, 6), Vector4(4, 4, 4, 4)))
	theme.set_stylebox("hover_pressed", "TileButton", _frame(slots, Rect2(64, 0, 32, 32), Vector4(6, 6, 6, 6), Vector4(4, 4, 4, 4)))
	theme.set_stylebox("focus", "TileButton", StyleBoxEmpty.new())

	var panel: Texture2D = load(DD + "20251029darkDwellers9SlicesE.png")
	var panel_box := _frame(panel, Rect2(0, 0, 96, 96), Vector4(14, 14, 14, 14), Vector4(10, 8, 10, 8))
	theme.set_stylebox("panel", "PanelContainer", panel_box)
	theme.set_stylebox("panel", "TooltipPanel", panel_box)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "TooltipLabel", TEXT)

	var err := ResourceSaver.save(theme, "res://ui/theme.tres")
	print("theme saved: ", error_string(err))
	quit()
