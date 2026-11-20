extends SceneTree
## Writes the corpse pile's tile sheet (gore_tiles.gd) as a picture, in plain colours, for review.
##   OUT=/tmp/gore_tiles.png godot --headless -s res://gore_tiles_preview.gd      (from a scratch copy's root)
func _initialize() -> void:
	var img := GoreTiles.preview()
	img.resize(img.get_width() * 5, img.get_height() * 5, Image.INTERPOLATE_NEAREST)
	img.save_png(OS.get_environment("OUT"))
	quit()
