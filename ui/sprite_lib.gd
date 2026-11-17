class_name SpriteLib
extends RefCounted
## Looks up the generated pixel-art sprites (tools/gen_sprites.gd). Missing sprites return null,
## so callers fall back to the emoji placeholders.

const ROOT := "res://assets/sprites/"
## Characters are drawn 16x24 (+1px outline margin) and shown at 2x.
const CHAR_SCALE := 2

static var _cache := {}


static func get_tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := ROOT + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t


## Named crew members get their own sprite; everyone else uses their role's.
static func crew(c: Character) -> Texture2D:
	var own := get_tex("crew/" + c.name.to_lower())
	return own if own else get_tex("crew/" + c.role)


static func customer(type_id: String) -> Texture2D:
	return get_tex("customers/" + type_id)


static func ingredient(id: String) -> Texture2D:
	return get_tex("ingredients/" + id)


## A crisp (nearest-filtered) TextureRect showing `tex` at `scale`x.
static func view(tex: Texture2D, scale: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = tex.get_size() * scale
	r.custom_minimum_size = r.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
