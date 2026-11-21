class_name Outline
## The outline round characters (owner, 21 Nov 2026), drawn by outline.gdshader as each body mesh's
## material_overlay. One shared material per kind, so a crowd costs no per-object material values beyond the
## flash; the approved character shaders and models are not touched.
##
## Kinds (owner's picks):
## - ZOMBIE: dark. Its flash colour is pale, for one coming into view.
## - RAIDER: dark red. Its flash is bright red.
## - ALLY: light: the player, and later allied people and other players, all the same.
## Dead bodies have none (owner: with this many zombies it is fine to know one is dead). Downed ones keep it.
## Cut-off pieces and the corpse pile never get one (a live arm in the pile must look like a dead one).

enum { ZOMBIE, RAIDER, ALLY }

const SHADER := preload("res://outline.gdshader")

## How long an enemy that comes into view flashes, and how long it must have been out of view first, so a crowd
## going in and out at the edge of sight doesn't flicker.
const SEEN_FLASH := 0.35
const SEEN_AFTER := 3.0

static var _mats := {}


static func material(kind: int) -> ShaderMaterial:
	if not _mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		match kind:
			ZOMBIE:
				m.set_shader_parameter("color", Color(0.09, 0.075, 0.06))
				m.set_shader_parameter("flash_color", Color(0.66, 0.68, 0.56))
				m.set_shader_parameter("wound_codes_from", 12.0)
			RAIDER:
				m.set_shader_parameter("color", Color(0.34, 0.04, 0.035))
				m.set_shader_parameter("flash_color", Color(0.95, 0.2, 0.14))
			ALLY:
				m.set_shader_parameter("color", Color(0.9, 0.87, 0.74))
				m.set_shader_parameter("flash_color", Color(0.9, 0.87, 0.74))
		_mats[kind] = m
	return _mats[kind]


## Put the outline on these meshes, or take it off (kind -1). Only touches a mesh that differs.
static func apply(meshes: Array, kind: int) -> void:
	var m: Material = null if kind < 0 else material(kind)
	for mi in meshes:
		var g := mi as GeometryInstance3D
		if g != null and g.material_overlay != m:
			g.material_overlay = m


## Set the flash values on these meshes (0 or 1 each).
static func flash(meshes: Array, seen: float, warn: float) -> void:
	for mi in meshes:
		var g := mi as GeometryInstance3D
		if g == null:
			continue
		g.set_instance_shader_parameter("outline_flash", seen)
		g.set_instance_shader_parameter("outline_warn", warn)
