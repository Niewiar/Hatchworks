@tool
extends RefCounted


static func inspect_layout(image: Image, tile_size: Vector2i, gap: int, margin: int = 0) -> Dictionary:
	if image == null or image.is_empty():
		return {"ok": false, "error": "Choose a source texture."}
	if tile_size.x <= 0 or tile_size.y <= 0 or gap < 0 or margin < 0:
		return {"ok": false, "error": "Tile dimensions must be positive. Spacing and margin cannot be negative."}
	var usable := image.get_size() - Vector2i(margin, margin) * 2
	var step := tile_size + Vector2i(gap, gap)
	if usable.x < tile_size.x or usable.y < tile_size.y:
		return {"ok": false, "error": "The tile does not fit inside the image. Check the tile size and margin."}
	if (usable.x + gap) % step.x != 0 or (usable.y + gap) % step.y != 0:
		return {"ok": false, "error": "Image dimensions do not match the tile grid. Check the tile size, spacing and outer margin."}
	var columns := floori(float(usable.x + gap) / float(step.x))
	var rows := floori(float(usable.y + gap) / float(step.y))
	return {
		"ok": true,
		"columns": columns,
		"rows": rows,
		"layers": columns * rows,
		"output_size": Vector2i(columns, rows) * tile_size,
		"tile_size": tile_size,
		"gap": gap,
		"margin": margin,
	}


static func split_tiles(image: Image, tile_size: Vector2i, gap: int, margin: int = 0) -> Dictionary:
	var info := inspect_layout(image, tile_size, gap, margin)
	if not info.ok:
		return info
	var source := image.duplicate() as Image
	if source.is_compressed() and source.decompress() != OK:
		return {"ok": false, "error": "Could not decompress the source image."}
	source.clear_mipmaps()
	source.convert(Image.FORMAT_RGBA8)
	var tiles: Array[Image] = []
	var step := tile_size + Vector2i(gap, gap)
	for row in range(info.rows):
		for column in range(info.columns):
			var origin := Vector2i(margin, margin) + Vector2i(column, row) * step
			tiles.append(source.get_region(Rect2i(origin, tile_size)))
	info["tiles"] = tiles
	return info


static func pack_image(image: Image, tile_size: Vector2i, gap: int, margin: int = 0) -> Dictionary:
	var result := split_tiles(image, tile_size, gap, margin)
	if not result.ok:
		return result
	var packed := Image.create(result.output_size.x, result.output_size.y, false, Image.FORMAT_RGBA8)
	var tiles: Array[Image] = result.tiles
	for row in range(result.rows):
		for column in range(result.columns):
			packed.blit_rect(tiles[row * result.columns + column], Rect2i(Vector2i.ZERO, tile_size), Vector2i(column, row) * tile_size)
	result["image"] = packed
	return result


static func create_array(tiles: Array[Image]) -> Dictionary:
	if tiles.is_empty():
		return {"ok": false, "error": "There are no tiles to save."}
	var resource := Texture2DArray.new()
	var error := resource.create_from_images(tiles)
	if error != OK:
		return {"ok": false, "error": "Could not create Texture2DArray: %s." % error_string(error)}
	return {"ok": true, "resource": resource}
