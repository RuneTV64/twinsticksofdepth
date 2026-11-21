extends SceneTree
## Headless test of the street kit's lamps and signs (assets/buildings/street) in the real level: what a lit
## lamp does at night, shooting one out, bringing a post down, and what a sign is for. Run from a scratch copy
## (copy this file to its root):
##   godot --headless --fixed-fps 60 -s res://lamp_test.gd

var main: Node
var p: Player


func _init() -> void:
	_run.call_deferred()


func _say(t: String) -> void:
	print("[lamp] ", t)


func _wait(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


## Put the crosshair where the camera sees this point of the world, and say what it is then on.
func _point_at(q: Vector3) -> String:
	var c := root.get_viewport().get_camera_3d().global_position
	var g := c + (q - c) * ((c.y - p.global_position.y) / maxf(c.y - q.y, 0.01))
	p.reticle_offset = g - p.global_position
	p.reticle_offset.y = 0.0
	p.armed = true
	p.reticle_visible = true
	p._update_hover()
	if p.aim_high == null:
		return "nothing above head height"
	return "the %s (%s), at height %.1f" % [p.aim_high.title, Materials.of(p.aim_high.stuff)["name"], p.aim_high_at.y]


func _lantern(near: Vector2) -> Breakable:
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.title == "street lamp" and b.rect.get_center().distance_to(near) < 1.0:
			return b
	return null


func _post(near: Vector2, what: String) -> Breakable:
	var best: Breakable = null
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.title == what and (best == null or b.rect.get_center().distance_to(near) < best.rect.get_center().distance_to(near)):
			best = b
	return best


func _wreck(near: Vector3) -> String:
	var out := []
	for w in Wreck.all:
		if is_instance_valid(w) and w.global_position.distance_to(near) < 1.5:
			for m: String in w.lot:
				out.append("%d %s" % [w.left(m), Materials.of(m)["name"]])
	return ", ".join(out) if not out.is_empty() else "nothing"


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	p = main.player
	p.invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	if Horde.it != null:
		Horde.it.set_process(false)
		Horde.it.set_physics_process(false)
	await _wait(0.2)
	var count := {}
	var reads := {}
	for b: Breakable in get_nodes_in_group("destructible"):
		if b.title in ["street lamp", "lamp post", "stop sign", "street sign", "warning sign"]:
			count[b.title] = int(count.get(b.title, 0)) + 1
	for n in get_nodes_in_group("interactables"):
		if n is StreetSign:
			reads[n.text] = int(reads.get(n.text, 0)) + 1
	_say("in the level: %s; lit lamps the daylight knows of: %d; the signs read: %s" % [count, Daylight.lamps.size(), reads])
	# ---- what a lit lamp does at night
	Daylight.level = 0.0
	Daylight.want = 0.0
	var foot := Vector3(3.625, 0.0, -62.5)
	var dark := Vector3(-0.5, 0.0, -80.5)
	p.global_position = foot + Vector3(0.6, 0.05, 0.0)
	await _wait(0.3)
	var seen_lit := p.seen_mult()
	p.global_position = dark + Vector3(0.0, 0.05, 0.0)
	await _wait(0.3)
	var seen_dark := p.seen_mult()
	_say("at night: under a lamp the light is %.2f and you are seen from %.2f of the daytime distance; in the middle of the crossroads, %.2f and %.2f" % [
		Daylight.at(foot), seen_lit, Daylight.at(dark), seen_dark])
	var reach := []
	for d: float in [2.0, 4.0, 6.0, 8.0, 10.0]:
		reach.append("%.0f m %.2f" % [d, Daylight.at(foot + Vector3(0, 0, d))])
	_say("  its light along the ground: %s" % ", ".join(reach))
	# ---- shooting it out
	p.global_position = Vector3(3.6, 0.05, -55.0)
	p.weapon = "gun"
	p.mag = 6
	await _wait(1.0)
	var on := _point_at(Vector3(3.625, 3.75, -62.28))
	_say("7.5 m from the lamp, crosshair over its lantern: on %s; prompt: %s" % [on, p.interact_prompt()])
	p._fire_cd = 0.0
	p._fire()
	await _wait(0.6)
	_say("one shot: the lantern is %s; light at its foot now %.2f; lit lamps left: %d; on the ground under it: %s; the post still stands: %s" % [
		"whole" if _lantern(Vector2(3.625, -62.5)) != null else "gone", Daylight.at(foot), Daylight.lamps.size(), _wreck(foot),
		_post(Vector2(3.625, -62.5), "lamp post") != null and _post(Vector2(3.625, -62.5), "lamp post").rect.get_center().distance_to(Vector2(3.625, -62.5)) < 0.5])
	# ---- a rock does it too
	p.inv.add(Items.make("rock", 2))
	p.weapon = "throw"
	p.global_position = Vector3(3.6, 0.05, -38.0)
	await _wait(0.8)
	on = _point_at(Vector3(3.625, 3.75, -44.28))
	p._fire_cd = 0.0
	p._throw()
	await _wait(2.5)
	_say("a rock thrown from 6.5 m with the crosshair on %s: the lantern is %s; lit lamps left: %d" % [on,
		"whole" if _lantern(Vector2(3.625, -44.5)) != null else "gone", Daylight.lamps.size()])
	# ---- bringing a post down
	var post := _post(Vector2(-4.625, -53.5), "lamp post")
	var foot2 := Vector3(-4.625, 0.0, -53.5)
	var before := Daylight.at(foot2)
	_say("a lamp post: %.0f sledgehammer blows, %.0f with the hatchet, %.0f blows from a zombie; fists: %s" % [
		ceilf(post.hits_left(p.break_sledge, "pound")), ceilf(post.hits_left(p.break_hatchet, "chop")), ceilf(post.hits_left(12.0, "blunt")), post.feel(p.break_fist, "blunt")])
	var n := 0
	while is_instance_valid(post) and post.alive() and n < 400:
		post.hit(p.break_sledge, "pound", foot2 + Vector3(0, 1, 0), p)
		n += 1
	await _wait(0.3)
	_say("brought down in %d blows: its lantern is %s; light at its foot %.2f, was %.2f; what is left: %s" % [n,
		"whole" if _lantern(Vector2(-4.625, -53.5)) != null else "gone", Daylight.at(foot2), before, _wreck(foot2)])
	# ---- a sign
	var sign := _post(Vector2(0, -80), "stop sign")
	var at := Vector3(sign.rect.get_center().x, 1.0, sign.rect.get_center().y)
	_say("a stop sign's post: %.0f sledgehammer blows, %.0f with the hatchet, %.0f from a zombie; a blow on it is heard %.0f m off" % [
		ceilf(sign.hits_left(p.break_sledge, "pound")), ceilf(sign.hits_left(p.break_hatchet, "chop")), ceilf(sign.hits_left(12.0, "blunt")),
		float(Materials.of("metal")["noise"])])
	var heard := 0
	var zs: Array[Enemy] = []
	for d: float in [5.0, 9.0, 14.0]:
		var z := Enemy.new()
		z.kind = "shambler"
		z.position = at + Vector3(d, -0.9, 0.0)
		main.add_child(z)
		z.player = p
		zs.append(z)
	p.global_position = at + Vector3(0.0, -0.95, 30.0)      # (the player well away, so it is the sign they come to)
	await _wait(0.3)
	sign.hit(p.break_fist, "blunt", at, p)
	await _wait(0.2)
	var who := []
	for i in zs.size():
		who.append("%s m: %s" % [["5", "9", "14"][i], "turned to it" if zs[i]._drive > 0.0 else "did not hear"])
	_say("the sign punched once, zombies standing off it: %s" % "; ".join(who))
	var texts := []
	for nn in get_nodes_in_group("interactables"):
		if nn is StreetSign and nn.global_position.distance_to(at) < 12.0:
			texts.append(nn.prompt_text(p))
	_say("walking up to the signs at the crossroads: %s" % [texts])
	quit()
