extends Node3D

const GRID_SIZE := 8
const CELL := 1.08
const BASE_TYPES := 6
const ROCKET_H := 6
const ROCKET_V := 7
const WRAPPED_BOMB := 8
const COLOR_BOMB := 9

var grid: Array = []
var touch_start := Vector2i(-1, -1)
var moves := 30
var score := 0
var busy := false
var candy_materials: Array[StandardMaterial3D] = []
var special_materials: Array[StandardMaterial3D] = []
var tile_materials: Array[StandardMaterial3D] = []

@onready var camera: Camera3D = $Camera3D
@onready var moves_label: Label = $HUD/TopPanel/Stats/Moves
@onready var score_label: Label = $HUD/TopPanel/Stats/Score
@onready var hint_label: Label = $HUD/Hint

func _ready() -> void:
	randomize()
	_make_materials()
	_make_board()
	_fill_grid()
	_update_hud()

func _make_materials() -> void:
	var colors := [
		Color("#ff477e"), Color("#39c9ff"), Color("#ffd447"),
		Color("#8d65ff"), Color("#4be39a"), Color("#ff914d")
	]
	for color in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.08
		material.roughness = 0.2
		material.clearcoat_enabled = true
		material.clearcoat = 0.7
		candy_materials.append(material)
	for color in [Color("#ffdc55"), Color("#ff8a3d"), Color("#f7f4ff"), Color("#fff1a6")]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.22
		material.roughness = 0.16
		material.clearcoat_enabled = true
		material.clearcoat = 0.9
		special_materials.append(material)
	for i in range(2):
		var tile := StandardMaterial3D.new()
		tile.albedo_color = Color("#382d62") if i == 0 else Color("#493875")
		tile.roughness = 0.55
		tile_materials.append(tile)

func _make_board() -> void:
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(GRID_SIZE * CELL + 0.34, GRID_SIZE * CELL + 0.34, 0.28)
	var back := MeshInstance3D.new()
	back.mesh = back_mesh
	back.position = Vector3(0, 0, -0.24)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color("#21183f")
	back_mat.roughness = 0.8
	back.material_override = back_mat
	add_child(back)
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(CELL * 0.96, CELL * 0.96, 0.12)
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.position = _cell_position(Vector2i(x, y), -0.04)
			tile.material_override = tile_materials[(x + y) % 2]
			add_child(tile)

func _fill_grid() -> void:
	grid.clear()
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			var kind := randi_range(0, BASE_TYPES - 1)
			while (x >= 2 and row[x - 1] == kind and row[x - 2] == kind) or (y >= 2 and grid[y - 1][x] == kind and grid[y - 2][x] == kind):
				kind = randi_range(0, BASE_TYPES - 1)
			row.append(kind)
			_create_candy(Vector2i(x, y), kind)
		grid.append(row)

func _cell_position(cell: Vector2i, z_value: float = 0.42) -> Vector3:
	return Vector3((cell.x - (GRID_SIZE - 1) * 0.5) * CELL, ((GRID_SIZE - 1) * 0.5 - cell.y) * CELL, z_value)

func _create_candy(cell: Vector2i, kind: int, spawn_above := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Candy_%d_%d" % [cell.x, cell.y]
	root.position = _cell_position(cell)
	if spawn_above:
		root.position.y += CELL * float(cell.y + 1)
	root.set_meta("cell", cell)
	root.set_meta("kind", kind)
	add_child(root)

	var body := MeshInstance3D.new()
	match kind:
		0, 4, 5, WRAPPED_BOMB, COLOR_BOMB:
			var mesh := SphereMesh.new()
			mesh.radius = 0.38 if kind < BASE_TYPES else 0.4
			mesh.height = mesh.radius * 2.0
			body.mesh = mesh
			if kind == 4:
				body.scale = Vector3(1.0, 1.0, 0.82)
			elif kind == 5:
				body.scale = Vector3(0.82, 1.0, 1.0)
		1:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.68, 0.68, 0.58)
			body.mesh = mesh
			body.rotation_degrees.z = 12
		2, ROCKET_H, ROCKET_V:
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.29 if kind == 2 else 0.24
			mesh.height = 0.82 if kind == 2 else 0.94
			body.mesh = mesh
			if kind == 2 or kind == ROCKET_H:
				body.rotation_degrees.z = 90
		3:
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.31
			mesh.bottom_radius = 0.38
			mesh.height = 0.68
			body.mesh = mesh
	body.material_override = candy_materials[kind] if kind < BASE_TYPES else special_materials[kind - BASE_TYPES]
	root.add_child(body)

	var shine := MeshInstance3D.new()
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = 0.085
	shine_mesh.height = 0.17
	shine.mesh = shine_mesh
	shine.position = Vector3(-0.13, 0.16, 0.29)
	var shine_mat := StandardMaterial3D.new()
	shine_mat.albedo_color = Color(1, 1, 1, 0.82)
	shine_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.material_override = shine_mat
	root.add_child(shine)

	if kind == ROCKET_H or kind == ROCKET_V:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.15, 0.18, 0.62)
		stripe.mesh = stripe_mesh
		stripe.material_override = special_materials[2]
		root.add_child(stripe)
	elif kind == WRAPPED_BOMB:
		for angle in [0.0, 90.0]:
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.13, 0.78, 0.62)
			band.mesh = band_mesh
			band.rotation_degrees.z = angle
			band.material_override = special_materials[0]
			root.add_child(band)
	elif kind == COLOR_BOMB:
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.12
		spark_mesh.height = 0.24
		spark.mesh = spark_mesh
		spark.position = Vector3(0.18, 0.18, 0.3)
		spark.material_override = special_materials[0]
		root.add_child(spark)
	return root

func _input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = _screen_to_cell(event.position)
		else:
			_handle_drag(touch_start, _screen_to_cell(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start = _screen_to_cell(event.position)
		else:
			_handle_drag(touch_start, _screen_to_cell(event.position))

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var hit = Plane(Vector3.FORWARD, 0.0).intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return Vector2i(-1, -1)
	var point: Vector3 = hit
	var x := roundi(point.x / CELL + (GRID_SIZE - 1) * 0.5)
	var y := roundi((GRID_SIZE - 1) * 0.5 - point.y / CELL)
	var cell := Vector2i(x, y)
	return cell if _inside(cell) else Vector2i(-1, -1)

func _handle_drag(a: Vector2i, b: Vector2i) -> void:
	if not _inside(a) or not _inside(b):
		return
	if a == b:
		hint_label.text = "اسحب الحلوى إلى خانة مجاورة"
		return
	if absi(a.x - b.x) + absi(a.y - b.y) == 1:
		_try_swap(a, b)

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	busy = true
	var kind_a: int = grid[a.y][a.x]
	var kind_b: int = grid[b.y][b.x]
	_swap_data(a, b)
	await _animate_swap(a, b)

	var match_data: Dictionary = {}
	if kind_a >= ROCKET_H or kind_b >= ROCKET_H:
		var special_matches: Dictionary = {}
		if kind_a >= ROCKET_H:
			_add_special_effect(b, kind_a, kind_b, special_matches)
		if kind_b >= ROCKET_H:
			_add_special_effect(a, kind_b, kind_a, special_matches)
		_expand_special_chains(special_matches, kind_a if kind_a < BASE_TYPES else kind_b)
		match_data = {"cells": special_matches, "special_cell": Vector2i(-1, -1), "special_kind": -1}
	else:
		match_data = _analyze_matches(b)
		if not (match_data["cells"] as Dictionary).is_empty():
			_expand_special_chains(match_data["cells"], kind_a)

	if (match_data["cells"] as Dictionary).is_empty():
		_swap_data(a, b)
		await _animate_swap(a, b)
		hint_label.text = "مفيش تطابق — جرّب حركة تانية"
	else:
		moves -= 1
		await _resolve_matches(match_data)
	busy = false
	_update_hud()

func _swap_data(a: Vector2i, b: Vector2i) -> void:
	var temp = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp

func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	var candy_a := _find_candy(a)
	var candy_b := _find_candy(b)
	if candy_a == null or candy_b == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(candy_a, "position", _cell_position(b), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(candy_b, "position", _cell_position(a), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	candy_a.set_meta("cell", b)
	candy_b.set_meta("cell", a)
	candy_a.name = "Candy_%d_%d" % [b.x, b.y]
	candy_b.name = "Candy_%d_%d" % [a.x, a.y]

func _find_candy(cell: Vector2i) -> Node3D:
	for child in get_children():
		if child is Node3D and child.has_meta("cell") and child.get_meta("cell") == cell:
			return child
	return null

func _analyze_matches(preferred_anchor: Vector2i) -> Dictionary:
	var found: Dictionary = {}
	var horizontal_runs: Array[Dictionary] = []
	var vertical_runs: Array[Dictionary] = []

	for y in range(GRID_SIZE):
		var x := 0
		while x < GRID_SIZE:
			var kind: int = grid[y][x]
			var end := x + 1
			while kind >= 0 and end < GRID_SIZE and grid[y][end] == kind:
				end += 1
			if kind >= 0 and end - x >= 3:
				var cells: Array[Vector2i] = []
				for column in range(x, end):
					var cell := Vector2i(column, y)
					cells.append(cell)
					found[cell] = true
				horizontal_runs.append({"cells": cells, "length": end - x})
			x = end

	for x in range(GRID_SIZE):
		var y := 0
		while y < GRID_SIZE:
			var kind: int = grid[y][x]
			var end := y + 1
			while kind >= 0 and end < GRID_SIZE and grid[end][x] == kind:
				end += 1
			if kind >= 0 and end - y >= 3:
				var cells: Array[Vector2i] = []
				for row in range(y, end):
					var cell := Vector2i(x, row)
					cells.append(cell)
					found[cell] = true
				vertical_runs.append({"cells": cells, "length": end - y})
			y = end

	var intersections: Array[Vector2i] = []
	for cell in found.keys():
		var in_horizontal := false
		var in_vertical := false
		for run in horizontal_runs:
			if run["cells"].has(cell):
				in_horizontal = true
				break
		for run in vertical_runs:
			if run["cells"].has(cell):
				in_vertical = true
				break
		if in_horizontal and in_vertical:
			intersections.append(cell)

	var special_cell := Vector2i(-1, -1)
	var special_kind := -1
	if not intersections.is_empty():
		special_cell = preferred_anchor if intersections.has(preferred_anchor) else intersections[0]
		special_kind = WRAPPED_BOMB
	else:
		var best_run: Dictionary = {}
		for run in horizontal_runs + vertical_runs:
			if run["length"] > best_run.get("length", 0):
				best_run = run
		if not best_run.is_empty() and best_run["length"] >= 5:
			var run_cells: Array = best_run["cells"]
			special_cell = preferred_anchor if run_cells.has(preferred_anchor) else run_cells[int(run_cells.size() / 2)]
			special_kind = COLOR_BOMB
		elif not best_run.is_empty() and best_run["length"] == 4:
			var run_cells: Array = best_run["cells"]
			special_cell = preferred_anchor if run_cells.has(preferred_anchor) else run_cells[1]
			special_kind = ROCKET_H if horizontal_runs.has(best_run) else ROCKET_V

	return {"cells": found, "special_cell": special_cell, "special_kind": special_kind}

func _find_matches() -> Dictionary:
	return _analyze_matches(Vector2i(-1, -1))["cells"]

func _add_special_effect(cell: Vector2i, special_kind: int, target_kind: int, matches: Dictionary) -> void:
	if not _inside(cell):
		return
	match special_kind:
		ROCKET_H:
			for x in range(GRID_SIZE):
				matches[Vector2i(x, cell.y)] = true
		ROCKET_V:
			for y in range(GRID_SIZE):
				matches[Vector2i(cell.x, y)] = true
		WRAPPED_BOMB:
			for y in range(maxi(0, cell.y - 1), mini(GRID_SIZE, cell.y + 2)):
				for x in range(maxi(0, cell.x - 1), mini(GRID_SIZE, cell.x + 2)):
					matches[Vector2i(x, y)] = true
		COLOR_BOMB:
			var chosen_kind := target_kind
			if chosen_kind < 0 or chosen_kind >= BASE_TYPES:
				chosen_kind = randi_range(0, BASE_TYPES - 1)
			for y in range(GRID_SIZE):
				for x in range(GRID_SIZE):
					if grid[y][x] == chosen_kind:
						matches[Vector2i(x, y)] = true

func _expand_special_chains(matches: Dictionary, target_kind: int) -> void:
	var activated: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell in matches.keys():
		queue.append(cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if not _inside(cell) or activated.has(cell):
			continue
		activated[cell] = true
		var kind: int = grid[cell.y][cell.x]
		if kind >= ROCKET_H:
			_add_special_effect(cell, kind, target_kind, matches)
			for added_cell in matches.keys():
				if not activated.has(added_cell):
					queue.append(added_cell)

func _resolve_matches(initial_data: Dictionary) -> void:
	var pending: Dictionary = initial_data
	while true:
		var matches: Dictionary = pending.get("cells", {})
		if matches.is_empty():
			break
		var special_cell: Vector2i = pending.get("special_cell", Vector2i(-1, -1))
		var special_kind: int = pending.get("special_kind", -1)
		if special_kind >= 0 and _inside(special_cell) and matches.has(special_cell):
			matches.erase(special_cell)

		score += (matches.size() + (1 if special_kind >= 0 else 0)) * 60
		var clear_tween := create_tween().set_parallel(true)
		var has_clear_animation := false
		for cell in matches.keys():
			var candy := _find_candy(cell)
			if candy != null:
				clear_tween.tween_property(candy, "scale", Vector3.ZERO, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				has_clear_animation = true
		if special_kind >= 0:
			var anchor_candy := _find_candy(special_cell)
			if anchor_candy != null:
				clear_tween.tween_property(anchor_candy, "scale", Vector3(1.28, 1.28, 1.28), 0.17)
				has_clear_animation = true
		if has_clear_animation:
			await clear_tween.finished

		for cell in matches.keys():
			var candy := _find_candy(cell)
			if candy != null:
				remove_child(candy)
				candy.queue_free()
			grid[cell.y][cell.x] = -1

		if special_kind >= 0 and _inside(special_cell):
			var old_special := _find_candy(special_cell)
			if old_special != null:
				remove_child(old_special)
				old_special.queue_free()
			grid[special_cell.y][special_cell.x] = special_kind
			var new_special := _create_candy(special_cell, special_kind)
			new_special.scale = Vector3(0.2, 0.2, 0.2)
			var appear := create_tween()
			appear.tween_property(new_special, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await appear.finished

		await _drop_and_refill()
		await get_tree().create_timer(0.08).timeout
		var cascade := _find_matches()
		if cascade.is_empty():
			pending = {"cells": {}, "special_cell": Vector2i(-1, -1), "special_kind": -1}
		else:
			_expand_special_chains(cascade, -1)
			pending = {"cells": cascade, "special_cell": Vector2i(-1, -1), "special_kind": -1}
	hint_label.text = "حلو! كمّل مطابقة الحلوى"

func _drop_and_refill() -> void:
	var fall_tween := create_tween().set_parallel(true)
	var has_fall_animation := false
	for x in range(GRID_SIZE):
		var write_y := GRID_SIZE - 1
		for y in range(GRID_SIZE - 1, -1, -1):
			if grid[y][x] >= 0:
				if write_y != y:
					var kind: int = grid[y][x]
					grid[write_y][x] = kind
					grid[y][x] = -1
					var candy := _find_candy(Vector2i(x, y))
					if candy != null:
						var destination := Vector2i(x, write_y)
						candy.set_meta("cell", destination)
						candy.name = "Candy_%d_%d" % [x, write_y]
						fall_tween.tween_property(candy, "position", _cell_position(destination), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
						has_fall_animation = true
				write_y -= 1
		for y in range(write_y, -1, -1):
			var kind := randi_range(0, BASE_TYPES - 1)
			grid[y][x] = kind
			var new_candy := _create_candy(Vector2i(x, y), kind, true)
			fall_tween.tween_property(new_candy, "position", _cell_position(Vector2i(x, y)), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			has_fall_animation = true
	if has_fall_animation:
		await fall_tween.finished

func _update_hud() -> void:
	moves_label.text = "MOVES  %d" % moves
	score_label.text = "SCORE  %d" % score
