extends Node
## Renders each card face once with the 2D CardView into a tiny SubViewport and hands out the texture,
## so the 3D cards show exactly the pixel art the rest of the game uses.

const CardView := preload("res://ui/common/card_view.gd")

var _cache: Dictionary = {}

func texture_for(card) -> Texture2D:
	var key: int = card.rank * 4 + card.suit
	if _cache.has(key):
		return _cache[key]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 96)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var view := CardView.new()
	viewport.add_child(view)
	view.setup(card, true)
	_cache[key] = viewport.get_texture()
	return _cache[key]
