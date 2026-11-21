extends SceneTree
## Drafts the clothes' fit for a body (Clothes.measure): every landmark and size the clothes use, measured from
## the body's own skeleton and mesh and placed as the tuned body (the muscular male) places them. Prints it ready
## to paste into Clothes.BODIES under the body's own name; then check it on the clothes sheets and tune by eye.
## Run from a scratch copy (copy this file to its root):
##   MODEL=res://path/to/NewBody_mid.glb godot --headless -s res://body_fit.gd
## With no MODEL it measures the muscular male against itself: what comes out should be its own table.

func _init() -> void:
	_go.call_deferred()


func _mesh(path: String) -> MeshInstance3D:
	var m := (load(path) as PackedScene).instantiate()
	root.add_child(m)
	return m.find_children("*", "MeshInstance3D", true, false)[0]


func _go() -> void:
	var tuned := _mesh(PlayerBody.MODEL_PATH)
	var path := OS.get_environment("MODEL")
	var body := tuned if path == "" else _mesh(path)
	var d := Clothes.measure(body, tuned)
	var own := Clothes.BODIES[Clothes.DEFAULT_BODY]
	print("marks: ", JSON.stringify(d["marks"]))
	print("fit: ", JSON.stringify(d["fit"]))
	if path == "":
		var worst := 0.0
		for k in own["marks"]:
			worst = maxf(worst, absf(float(own["marks"][k]) - float(d["marks"].get(k, own["marks"][k]))))
		for k in own["fit"]:
			var a = own["fit"][k]
			var b = d["fit"][k]
			if a is Array:
				for j in a.size():
					worst = maxf(worst, absf(float(a[j]) - float(b[j])))
			else:
				worst = maxf(worst, absf(float(a) - float(b)))
		print("measured against itself: the furthest any number is from the tuned table: %.4f m" % worst)
	quit()
