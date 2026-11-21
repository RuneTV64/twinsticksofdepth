class_name GroundPit
extends RefCounted
## Holes in the ground, for basements (assets/buildings/house/house_kit.gd). The ground (assets/ground/ground.gd)
## is one flat slab; `cut(rect)` takes a rectangle out of it, both what is drawn and what is stood on, by
## rebuilding the slab as strips round every hole cut so far. Whatever is built in the hole has to bring its
## own floor and walls. Done once, when the level is built; nothing runs afterwards.

static var holes: Array[Rect2] = []


static func reset() -> void:
	holes.clear()


static func cut(rect: Rect2) -> void:
	holes.append(rect)
	if Ground.it != null:
		_rebuild(Ground.it)


static func _rebuild(g: Ground) -> void:
	var outer := g.area.grow(5.0)
	var xs: Array[float] = [outer.position.x, outer.end.x]
	var zs: Array[float] = [outer.position.y, outer.end.y]
	for h in holes:
		for x: float in [h.position.x, h.end.x]:
			if x > outer.position.x and x < outer.end.x and not xs.has(x):
				xs.append(x)
		for z: float in [h.position.y, h.end.y]:
			if z > outer.position.y and z < outer.end.y and not zs.has(z):
				zs.append(z)
	xs.sort()
	zs.sort()
	# Strips: along each row between two cuts, the runs of ground that aren't in a hole.
	var strips: Array[Rect2] = []
	for zi in zs.size() - 1:
		var start := -1
		for xi in xs.size():
			var solid := false
			if xi < xs.size() - 1:
				var mid := Vector2((xs[xi] + xs[xi + 1]) * 0.5, (zs[zi] + zs[zi + 1]) * 0.5)
				solid = true
				for h in holes:
					solid = solid and not h.has_point(mid)
			if solid and start < 0:
				start = xi
			elif not solid and start >= 0:
				strips.append(Rect2(xs[start], zs[zi], xs[xi] - xs[start], zs[zi + 1] - zs[zi]))
				start = -1
	for c in g.get_children():
		if c is CollisionShape3D:
			c.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in strips:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, 1.0, r.size.y)
		shape.shape = box
		shape.position = Vector3(r.get_center().x, -0.5, r.get_center().y)
		g.add_child(shape)
		var a := Vector3(r.position.x, 0.0, r.position.y)
		var b := Vector3(r.end.x, 0.0, r.position.y)
		var c := Vector3(r.end.x, 0.0, r.end.y)
		var d := Vector3(r.position.x, 0.0, r.end.y)
		for q: Vector3 in [a, b, c, a, c, d]:      # clockwise seen from above: Godot's front
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	g.mesh.mesh = st.commit()
	g.mesh.position = Vector3.ZERO
