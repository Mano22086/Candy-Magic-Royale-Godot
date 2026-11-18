extends Node3D

const GRID_SIZE := 8
const CELL := 1.08
const BASE_TYPES := 6
const ROCKET_H := 6
const ROCKET_V := 7
const WRAPPED_BOMB := 8
const COLOR_BOMB := 9

var grid: Array = []
var candy_textures: Array[Texture2D] = []
var special_textures: Dictionary = {}
var booster_textures: Dictionary = {}
var booster_counts: Dictionary = {"paint": 3, "shuffle": 3, "bomb": 3, "color": 3, "rocket": 3, "moves": 3}
var booster_buttons: Dictionary = {}
var active_booster := ""
var game_started := false
var start_layer: CanvasLayer
var map_layer: CanvasLayer
@export_enum("castle", "candy", "crystal") var board_theme: String = "castle"
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
	_make_booster_bar()
	_show_start_screen()
	_update_hud()

func _make_materials() -> void:
	for i in range(1, 7):
		candy_textures.append(load("res://assets/candies/candy_%02d.png" % i))
	special_textures = {
		"wrapped": load("res://assets/special/wrapped_candy.jpg"),
		"color": load("res://assets/special/chocolate_color_ball.jpg"),
		"swirl": load("res://assets/special/peppermint_swirl.jpg"),
		"gem": load("res://assets/special/rainbow_gem.jpg")
	}
	booster_textures = {
		"paint": load("res://assets/boosters/magic_wand.jpg"),
		"bomb": load("res://assets/special/wrapped_candy.jpg"),
		"color": load("res://assets/special/chocolate_color_ball.jpg"),
		"rocket": load("res://assets/boosters/rocket.jpg"),
		"moves": load("res://assets/boosters/extra_moves.jpg"),
		"hammer": load("res://assets/boosters/hammer.jpg")
	}
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
	_add_board_backdrop()
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

func _add_board_backdrop() -> void:
	var paths := {
		"castle": "res://assets/board/board-castle.svg",
		"candy": "res://assets/board/board-candy.svg",
		"crystal": "res://assets/board/board-crystal.svg"
	}
	var texture := load(paths.get(board_theme, paths["castle"])) as Texture2D
	if texture == null:
		push_warning("Board background missing; using the default dark board.")
		return
	var backdrop := Sprite3D.new()
	backdrop.name = "BoardBackdrop"
	backdrop.texture = texture
	backdrop.pixel_size = 16.2 / 1600.0
	backdrop.position = Vector3(0, 0, -0.82)
	backdrop.shaded = false
	add_child(backdrop)

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

func _make_art_sprite(texture: Texture2D, world_size: float, keyed := false) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	var longest := maxi(texture.get_width(), texture.get_height())
	sprite.pixel_size = world_size / float(maxi(1, longest))
	sprite.shaded = false
	if keyed:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D art_texture : source_color;
void fragment() {
	vec4 px = texture(art_texture, UV);
	if (distance(px.rgb, vec3(0.14, 0.18, 0.24)) < 0.17) {
		discard;
	}
	ALBEDO = px.rgb;
	ALPHA = px.a;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("art_texture", texture)
		sprite.material_override = material
	return sprite

func _create_candy(cell: Vector2i, kind: int, spawn_above := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Candy_%d_%d" % [cell.x, cell.y]
	root.position = _cell_position(cell)
	if spawn_above:
		root.position.y += CELL * float(cell.y + 1)
	root.set_meta("cell", cell)
	root.set_meta("kind", kind)
	add_child(root)

	var base_kind := kind if kind < BASE_TYPES else 0
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 0.68
	body.mesh = body_mesh
	body.material_override = candy_materials[base_kind]
	body.position.z = -0.04
	root.add_child(body)

	var artwork: Sprite3D
	if kind == ROCKET_H or kind == ROCKET_V:
		artwork = _make_art_sprite(booster_textures["rocket"], CELL * 0.94, true)
	elif kind == WRAPPED_BOMB:
		artwork = _make_art_sprite(special_textures["wrapped"], CELL * 0.92, true)
	elif kind == COLOR_BOMB:
		artwork = _make_art_sprite(special_textures["color"], CELL * 0.92, true)
	else:
		artwork = _make_art_sprite(candy_textures[kind], CELL * 0.86)
	artwork.position.z = 0.31
	root.add_child(artwork)
	return root

func _input(event: InputEvent) -> void:
	if busy or not game_started:
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
	if active_booster != "":
		if a == b:
			await _use_booster(a)
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
		if not match_data["cells"].is_empty():
			_expand_special_chains(match_data["cells"], kind_a)

	if match_data["cells"].is_empty():
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
	return get_node_or_null("Candy_%d_%d" % [cell.x, cell.y]) as Node3D

func _analyze_matches(preferred_anchor: Vector2i) -> Dictionary:
	var found: Dictionary = {}
	var horizontal_runs: Array[Dictionary] = []
	var vertical_runs: Array[Dictionary] = []

	for y in range(GRID_SIZE):
		var x := 0
		while x < GRID_SIZE:
			var kind: int = grid[y][x]
			var end := x + 1
			while kind >= 0 and kind < BASE_TYPES and end < GRID_SIZE and grid[y][end] == kind:
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
			while kind >= 0 and kind < BASE_TYPES and end < GRID_SIZE and grid[end][x] == kind:
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
	matches[cell] = true
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

func _spawn_special_fx(cell: Vector2i, kind: int) -> void:
	var fx := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	fx.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.2
	match kind:
		ROCKET_H, ROCKET_V:
			mat.albedo_color = Color("#75eaff", 0.82)
			mat.emission = Color("#2fdcff")
		WRAPPED_BOMB:
			mat.albedo_color = Color("#ff9b42", 0.86)
			mat.emission = Color("#ff5b18")
		COLOR_BOMB:
			mat.albedo_color = Color("#ff5de4", 0.88)
			mat.emission = Color("#a94cff")
	fx.material_override = mat
	fx.position = _cell_position(cell, 0.72)
	fx.scale = Vector3(0.35, 0.35, 0.35)
	add_child(fx)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(2.6, 2.6, 2.6), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, 0.0), 0.22)
	tw.chain().tween_callback(fx.queue_free)
	if kind == ROCKET_H or kind == ROCKET_V:
		var lane := MeshInstance3D.new()
		var lane_mesh := BoxMesh.new()
		lane_mesh.size = Vector3(GRID_SIZE * CELL, 0.14, 0.07) if kind == ROCKET_H else Vector3(0.14, GRID_SIZE * CELL, 0.07)
		lane.mesh = lane_mesh
		var lane_mat := StandardMaterial3D.new()
		lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lane_mat.albedo_color = Color("#6beaff", 0.9)
		lane_mat.emission_enabled = true
		lane_mat.emission = Color("#25dfff")
		lane_mat.emission_energy_multiplier = 3.0
		lane.material_override = lane_mat
		lane.position = _cell_position(cell, 0.60)
		lane.scale = Vector3(0.02, 1.0, 1.0) if kind == ROCKET_H else Vector3(1.0, 0.02, 1.0)
		add_child(lane)
		var lane_tw := create_tween().set_parallel(true)
		lane_tw.tween_property(lane, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		lane_tw.tween_property(lane_mat, "albedo_color", Color("#6beaff", 0.0), 0.2)
		lane_tw.chain().tween_callback(lane.queue_free)

func _spawn_clear_fx(cell: Vector2i) -> void:
	var fx := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	fx.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("#ffe99a", 0.9)
	mat.emission_enabled = true
	mat.emission = Color("#ffc94a")
	mat.emission_energy_multiplier = 1.5
	fx.material_override = mat
	fx.position = _cell_position(cell, 0.68)
	add_child(fx)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(2.0, 2.0, 2.0), 0.16)
	tw.tween_property(mat, "albedo_color", Color("#ffe99a", 0.0), 0.16)
	tw.chain().tween_callback(fx.queue_free)

func _resolve_matches(initial_data: Dictionary) -> void:
	var pending: Dictionary = initial_data
	var cascade_guard := 0
	while cascade_guard < 20:
		cascade_guard += 1
		var matches: Dictionary = pending.get("cells", {})
		if matches.is_empty():
			break
		var special_cell: Vector2i = pending.get("special_cell", Vector2i(-1, -1))
		var special_kind: int = pending.get("special_kind", -1)
		if special_kind >= 0 and _inside(special_cell) and matches.has(special_cell):
			matches.erase(special_cell)

		score += (matches.size() + (1 if special_kind >= 0 else 0)) * 60
		var activation_tween := create_tween().set_parallel(true)
		var has_activation := false
		for cell in matches.keys():
			if int(grid[cell.y][cell.x]) >= ROCKET_H:
				_spawn_special_fx(cell, int(grid[cell.y][cell.x]))
				var special_candy := _find_candy(cell)
				if special_candy != null:
					activation_tween.tween_property(special_candy, "scale", Vector3(1.55, 1.55, 1.55), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					activation_tween.tween_property(special_candy, "rotation_degrees", Vector3(0, 0, 360), 0.2)
					has_activation = true
		if has_activation:
			await activation_tween.finished
		var clear_tween := create_tween().set_parallel(true)
		var has_clear_animation := false
		for cell in matches.keys():
			_spawn_clear_fx(cell)
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
	if cascade_guard >= 20:
		hint_label.text = "تم إيقاف سلسلة التطابقات الطويلة لحماية الأداء"
	else:
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
			fall_tween.tween_property(new_candy, "position", _cell_position(Vector2i(x, y)), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			has_fall_animation = true
	if has_fall_animation:
		await fall_tween.finished

func _make_booster_bar() -> void:
	var panel: PanelContainer = $HUD/BottomPanel
	var old_label: Label = $HUD/BottomPanel/BottomText
	old_label.visible = false
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var items := [
		{"id": "paint", "label": "فرشاة", "texture": booster_textures["paint"]},
		{"id": "shuffle", "label": "خلط", "texture": null},
		{"id": "bomb", "label": "قنبلة", "texture": booster_textures["bomb"]},
		{"id": "color", "label": "ألوان", "texture": booster_textures["color"]},
		{"id": "rocket", "label": "صاروخ", "texture": booster_textures["rocket"]},
		{"id": "moves", "label": "+5 حركات", "texture": booster_textures["moves"]}
	]
	for item in items:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 112)
		button.text = item["label"] + "\n" + str(booster_counts[item["id"]])
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("#fff4d6"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		if item["texture"] != null:
			button.icon = item["texture"]
			button.expand_icon = true
		button.pressed.connect(_select_booster.bind(item["id"]))
		row.add_child(button)
		booster_buttons[item["id"]] = button
	_update_booster_bar()

func _update_booster_bar() -> void:
	for id in booster_buttons.keys():
		var button: Button = booster_buttons[id]
		button.text = {
			"paint": "فرشاة",
			"shuffle": "خلط",
			"bomb": "قنبلة",
			"color": "ألوان",
			"rocket": "صاروخ",
			"moves": "+5 حركات"
		}[id] + "\n" + str(booster_counts[id])
		button.disabled = booster_counts[id] <= 0
		button.modulate = Color("#ffe28a") if active_booster == id else Color.WHITE

func _select_booster(id: String) -> void:
	if busy or not game_started or booster_counts.get(id, 0) <= 0:
		return
	if id == "moves":
		booster_counts[id] -= 1
		moves += 5
		hint_label.text = "اتضافت 5 حركات!"
		_update_hud()
		return
	if id == "shuffle":
		booster_counts[id] -= 1
		_shuffle_board()
		active_booster = ""
		hint_label.text = "اتخلطت الحلوى — اللوحة جاهزة"
		_update_hud()
		return
	active_booster = "" if active_booster == id else id
	hint_label.text = "اختار حلوى على اللوحة لاستخدام " + {
		"paint": "الفرشاة",
		"bomb": "القنبلة",
		"color": "كرة الألوان",
		"rocket": "الصاروخ"
	}[id] if active_booster != "" else "تم إلغاء المساعدة"
	_update_booster_bar()

func _use_booster(cell: Vector2i) -> void:
	if active_booster == "" or busy or booster_counts.get(active_booster, 0) <= 0:
		return
	busy = true
	var used := active_booster
	active_booster = ""
	var cells: Dictionary = {}
	var original_kind: int = grid[cell.y][cell.x]
	match used:
		"paint":
			var new_kind := _best_paint_kind(cell)
			grid[cell.y][cell.x] = new_kind
			var old_candy := _find_candy(cell)
			if old_candy != null:
				remove_child(old_candy)
				old_candy.queue_free()
			_create_candy(cell, new_kind)
			cells = _find_matches()
			if not cells.is_empty():
				_expand_special_chains(cells, -1)
		"bomb":
			_spawn_special_fx(cell, WRAPPED_BOMB)
			for y in range(maxi(0, cell.y - 1), mini(GRID_SIZE, cell.y + 2)):
				for x in range(maxi(0, cell.x - 1), mini(GRID_SIZE, cell.x + 2)):
					cells[Vector2i(x, y)] = true
		"color":
			if original_kind < 0 or original_kind >= BASE_TYPES:
				active_booster = "color"
				busy = false
				hint_label.text = "اختار حلوى عادية عشان تحدد لون كرة الألوان"
				_update_booster_bar()
				return
			_spawn_special_fx(cell, COLOR_BOMB)
			for y in range(GRID_SIZE):
				for x in range(GRID_SIZE):
					if grid[y][x] == original_kind:
						cells[Vector2i(x, y)] = true
		"rocket":
			_spawn_special_fx(cell, ROCKET_H)
			for x in range(GRID_SIZE):
				cells[Vector2i(x, cell.y)] = true
	if used != "paint" or not cells.is_empty():
		if not cells.is_empty():
			_expand_special_chains(cells, original_kind)
			await _resolve_matches({"cells": cells, "special_cell": Vector2i(-1, -1), "special_kind": -1})
	booster_counts[used] -= 1
	moves = maxi(0, moves - 1)
	busy = false
	hint_label.text = "اتستخدمت المساعدة بنجاح"
	_update_hud()

func _best_paint_kind(cell: Vector2i) -> int:
	var old_kind: int = grid[cell.y][cell.x]
	var best_kind := old_kind
	var best_run := 1
	for kind in range(BASE_TYPES):
		grid[cell.y][cell.x] = kind
		var run := _run_length_at(cell, kind)
		if run > best_run:
			best_run = run
			best_kind = kind
	grid[cell.y][cell.x] = old_kind
	if best_kind == old_kind:
		var counts := {}
		for row in grid:
			for value in row:
				if value >= 0 and value < BASE_TYPES:
					counts[value] = counts.get(value, 0) + 1
		var most_common := old_kind
		var highest := -1
		for kind in counts.keys():
			if counts[kind] > highest:
				highest = counts[kind]
				most_common = kind
		best_kind = most_common
		if best_kind == old_kind:
			best_kind = (old_kind + 1) % BASE_TYPES
	return best_kind

func _run_length_at(cell: Vector2i, kind: int) -> int:
	var horizontal := 1
	var x := cell.x - 1
	while x >= 0 and grid[cell.y][x] == kind:
		horizontal += 1
		x -= 1
	x = cell.x + 1
	while x < GRID_SIZE and grid[cell.y][x] == kind:
		horizontal += 1
		x += 1
	var vertical := 1
	var y := cell.y - 1
	while y >= 0 and grid[y][cell.x] == kind:
		vertical += 1
		y -= 1
	y = cell.y + 1
	while y < GRID_SIZE and grid[y][cell.x] == kind:
		vertical += 1
		y += 1
	return maxi(horizontal, vertical)

func _shuffle_board() -> void:
	if busy:
		return
	var positions: Array[Vector2i] = []
	var values: Array[int] = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if grid[y][x] < BASE_TYPES:
				positions.append(Vector2i(x, y))
				values.append(grid[y][x])
	var playable := false
	for attempt in range(50):
		values.shuffle()
		for i in range(positions.size()):
			var cell: Vector2i = positions[i]
			grid[cell.y][cell.x] = values[i]
		if _find_matches().is_empty() and _has_possible_move():
			playable = true
			break
	if not playable:
		for i in range(positions.size()):
			var cell: Vector2i = positions[i]
			grid[cell.y][cell.x] = randi_range(0, BASE_TYPES - 1)
	_refresh_all_candies()

func _has_possible_move() -> bool:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other := Vector2i(x, y) + direction
				if not _inside(other):
					continue
				_swap_data(Vector2i(x, y), other)
				var possible := not _find_matches().is_empty()
				_swap_data(Vector2i(x, y), other)
				if possible:
					return true
	return false

func _refresh_all_candies() -> void:
	for child in get_children():
		if child is Node3D and child.has_meta("cell"):
			remove_child(child)
			child.queue_free()
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if grid[y][x] >= 0:
				_create_candy(Vector2i(x, y), grid[y][x])

func _show_start_screen() -> void:
	start_layer = CanvasLayer.new()
	start_layer.layer = 20
	add_child(start_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	start_layer.add_child(root)
	var base := ColorRect.new()
	base.color = Color("#241044")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	_add_start_image(root, "res://assets/start/enchanted-garden-backdrop.svg", 0, 0, 1, 1, TextureRect.STRETCH_KEEP_ASPECT_COVERED, Color(1, 1, 1, 0.62))
	_add_start_image(root, "res://assets/start/enchanted-castle.svg", 0.08, 0.22, 0.92, 0.84, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, Color(1, 1, 1, 0.88))
	_add_start_image(root, "res://assets/start/queen-luma.svg", 0.00, 0.32, 0.38, 0.73)
	_add_start_image(root, "res://assets/start/dragon-prince.svg", 0.62, 0.32, 1.00, 0.73)
	var stars := Label.new()
	stars.text = "✦     ✧       ✦       ✧     ✦"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 23)
	stars.add_theme_color_override("font_color", Color("#ffe7a5"))
	stars.anchor_left = 0.05
	stars.anchor_right = 0.95
	stars.anchor_top = 0.035
	stars.anchor_bottom = 0.09
	root.add_child(stars)
	var title := Label.new()
	title.text = "CANDY MAGIC\nROYALE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 43)
	title.add_theme_color_override("font_color", Color("#fff0b4"))
	title.add_theme_color_override("font_shadow_color", Color("#301044"))
	title.anchor_left = 0.08
	title.anchor_right = 0.92
	title.anchor_top = 0.10
	title.anchor_bottom = 0.28
	root.add_child(title)
	var tagline := Label.new()
	tagline.text = "MAGIC  •  SWEETS  •  ADVENTURE"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 12)
	tagline.add_theme_color_override("font_color", Color("#fff0c8"))
	tagline.anchor_left = 0.08
	tagline.anchor_right = 0.92
	tagline.anchor_top = 0.27
	tagline.anchor_bottom = 0.31
	root.add_child(tagline)
	var buttons := VBoxContainer.new()
	buttons.anchor_left = 0.13
	buttons.anchor_right = 0.87
	buttons.anchor_top = 0.78
	buttons.anchor_bottom = 0.97
	buttons.add_theme_constant_override("separation", 9)
	root.add_child(buttons)
	var guest := _make_start_button("GUEST PLAY")
	guest.pressed.connect(_open_world_map)
	buttons.add_child(guest)
	var facebook := _make_start_button("FACEBOOK PLAY")
	facebook.pressed.connect(_show_facebook_message)
	buttons.add_child(facebook)
	var footer := Label.new()
	footer.text = "CHOOSE YOUR WAY INTO THE KINGDOM"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color("#e9d4ff"))
	footer.anchor_left = 0.05
	footer.anchor_right = 0.95
	footer.anchor_top = 0.965
	footer.anchor_bottom = 0.995
	root.add_child(footer)
	var queen_node := root.get_child(3)
	var dragon_node := root.get_child(4)
	var float_tween := create_tween().set_loops()
	float_tween.tween_property(queen_node, "position:y", -8.0, 1.8).as_relative()
	float_tween.tween_property(queen_node, "position:y", 8.0, 1.8).as_relative()
	float_tween.parallel().tween_property(dragon_node, "rotation", 0.035, 1.6)
	float_tween.tween_property(dragon_node, "rotation", -0.035, 1.6)

func _add_start_image(parent: Control, path: String, left: float, top: float, right: float, bottom: float, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED, tint := Color.WHITE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = stretch
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.anchor_left = left
	image.anchor_top = top
	image.anchor_right = right
	image.anchor_bottom = bottom
	parent.add_child(image)
	return image

func _make_start_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("#4a2459"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#f6cf77")
	normal.border_color = Color("#fff0b8")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(17)
	normal.shadow_color = Color("#1a082d")
	normal.shadow_size = 6
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#ffe7a0")
	button.add_theme_stylebox_override("hover", hover)
	return button

func _open_world_map() -> void:
	if start_layer != null:
		start_layer.queue_free()
		start_layer = null
	map_layer = CanvasLayer.new()
	map_layer.layer = 20
	add_child(map_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_layer.add_child(root)
	var background := ColorRect.new()
	background.color = Color("#29134e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_add_start_image(root, "res://assets/start/world-map-background.svg", 0, 0, 1, 1, TextureRect.STRETCH_KEEP_ASPECT_COVERED, Color(1, 1, 1, 0.8))
	_add_start_image(root, "res://assets/start/royal-world-map.svg", 0.05, 0.14, 0.95, 0.76)
	var title := Label.new()
	title.text = "خريطة المملكة"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#ffe7a5"))
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.anchor_top = 0.04
	title.anchor_bottom = 0.13
	root.add_child(title)
	var play := _make_start_button("البيت الأول  —  العب الآن")
	play.anchor_left = 0.12
	play.anchor_right = 0.88
	play.anchor_top = 0.82
	play.anchor_bottom = 0.91
	play.pressed.connect(_launch_first_level)
	root.add_child(play)
	var back := Button.new()
	back.text = "رجوع"
	back.anchor_left = 0.35
	back.anchor_right = 0.65
	back.anchor_top = 0.925
	back.anchor_bottom = 0.98
	back.pressed.connect(_return_to_start)
	root.add_child(back)

func _return_to_start() -> void:
	if map_layer != null:
		map_layer.queue_free()
		map_layer = null
	_show_start_screen()

func _show_facebook_message() -> void:
	if start_layer == null:
		return
	var root := start_layer.get_child(0) as Control
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var card := PanelContainer.new()
	card.anchor_left = 0.08
	card.anchor_right = 0.92
	card.anchor_top = 0.34
	card.anchor_bottom = 0.68
	root.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var heading := Label.new()
	heading.text = "FACEBOOK PLAY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)
	var message := Label.new()
	message.text = "تسجيل الدخول الحقيقي بفيسبوك يحتاج إعداد تطبيق Meta ومفاتيح الربط. تقدر تبدأ كضيف دلوقتي."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)
	var guest := _make_start_button("العب كضيف دلوقتي")
	guest.pressed.connect(_open_world_map)
	content.add_child(guest)
	var back := Button.new()
	back.text = "رجوع"
	back.pressed.connect(func():
		overlay.queue_free()
		card.queue_free()
	)
	content.add_child(back)

func _launch_first_level() -> void:
	if map_layer != null:
		map_layer.queue_free()
		map_layer = null
	game_started = true
	hint_label.text = "بدّل الحلوى واجمع 3 أو أكثر!"
	_update_hud()

func _update_hud() -> void:
	moves_label.text = "MOVES  %d" % moves
	score_label.text = "SCORE  %d" % score
	_update_booster_bar()
