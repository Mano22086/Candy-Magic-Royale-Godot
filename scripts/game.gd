extends Node3D

const GRID_SIZE := 8
const CELL := 1.08
const CANDY_TYPES := 6

var grid: Array = []
var selected := Vector2i(-1, -1)
var touch_start := Vector2i(-1, -1)
var moves := 30
var score := 0
var busy := false
var candy_materials: Array[StandardMaterial3D] = []
var tile_materials: Array[StandardMaterial3D] = []

@onready var camera: Camera3D = $Camera3D
@onready var moves_label: Label = $HUD/TopPanel/Stats/Moves
@onready var score_label: Label = $HUD/TopPanel/Stats/Score
@onready var hint_label: Label = $HUD/Hint

func _ready() -> void:
	_make_materials()
	_make_board()
	_fill_grid()
	_update_hud()

func _make_materials() -> void:
	var colors := [
		Color("#ff477e"), Color("#39c9ff"), Color("#ffd447"),
		Color("#8d65ff"), Color("#4be39a"), Color("#ff914d")
	]
	for c in colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.08
		m.roughness = 0.2
		m.clearcoat_enabled = true
		m.clearcoat = 0.7
		candy_materials.append(m)
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
			var kind := randi_range(0, CANDY_TYPES - 1)
			while (x >= 2 and row[x - 1] == kind and row[x - 2] == kind) or (y >= 2 and grid[y - 1][x] == kind and grid[y - 2][x] == kind):
				kind = randi_range(0, CANDY_TYPES - 1)
			row.append(kind)
			_create_candy(Vector2i(x, y), kind)
		grid.append(row)

func _cell_position(cell: Vector2i, z_value: float = 0.42) -> Vector3:
	return Vector3((cell.x - (GRID_SIZE - 1) * 0.5) * CELL, ((GRID_SIZE - 1) * 0.5 - cell.y) * CELL, z_value)

func _create_candy(cell: Vector2i, kind: int) -> void:
	var root := Node3D.new()
	root.name = "Candy_%d_%d" % [cell.x, cell.y]
	root.position = _cell_position(cell)
	root.set_meta("cell", cell)
	root.set_meta("kind", kind)
	add_child(root)
	var body := MeshInstance3D.new()
	match kind:
		0:
			var mesh := SphereMesh.new()
			mesh.radius = 0.39
			mesh.height = 0.78
			body.mesh = mesh
		1:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.68, 0.68, 0.58)
			body.mesh = mesh
			body.rotation_degrees.z = 12
		2:
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.29
			mesh.height = 0.82
			body.mesh = mesh
			body.rotation_degrees.z = 90
		3:
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.31
			mesh.bottom_radius = 0.38
			mesh.height = 0.68
			body.mesh = mesh
		4:
			var mesh := SphereMesh.new()
			mesh.radius = 0.34
			mesh.height = 0.68
			body.mesh = mesh
			body.scale = Vector3(1.0, 1.0, 0.82)
		_:
			var mesh := SphereMesh.new()
			mesh.radius = 0.38
			mesh.height = 0.76
			body.mesh = mesh
			body.scale = Vector3(0.82, 1.0, 1.0)
	body.material_override = candy_materials[kind]
	root.add_child(body)
	var shine := MeshInstance3D.new()
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = 0.085
	shine_mesh.height = 0.17
	shine.mesh = shine_mesh
	shine.position = Vector3(-0.13, 0.16, 0.29)
	var shine_mat := StandardMaterial3D.new()
	shine_mat.albedo_color = Color(1, 1, 1, 0.78)
	shine_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.material_override = shine_mat
	root.add_child(shine)

func _input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = _screen_to_cell(event.position)
		else:
			var finish := _screen_to_cell(event.position)
			_handle_drag(touch_start, finish)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start = _screen_to_cell(event.position)
		else:
			var finish := _screen_to_cell(event.position)
			_handle_drag(touch_start, finish)

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var hit = Plane(Vector3.FORWARD, 0.0).intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return Vector2i(-1, -1)
	var p: Vector3 = hit
	var x := roundi(p.x / CELL + (GRID_SIZE - 1) * 0.5)
	var y := roundi((GRID_SIZE - 1) * 0.5 - p.y / CELL)
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _handle_drag(a: Vector2i, b: Vector2i) -> void:
	if not _inside(a) or not _inside(b):
		return
	if a == b:
		_select_cell(a)
		return
	if absi(a.x - b.x) + absi(a.y - b.y) == 1:
		selected = a
		_try_swap(a, b)

func _select_cell(cell: Vector2i) -> void:
	selected = cell
	hint_label.text = "Selected candy — swipe to swap"

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	busy = true
	_swap_data(a, b)
	await _animate_swap(a, b)
	var matches := _find_matches()
	if matches.is_empty():
		_swap_data(a, b)
		await _animate_swap(a, b)
		hint_label.text = "No match — try another move"
	else:
		moves -= 1
		await _resolve_matches(matches)
	busy = false
	_update_hud()

func _swap_data(a: Vector2i, b: Vector2i) -> void:
	var temp = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp

func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	var ca := _find_candy(a)
	var cb := _find_candy(b)
	if ca == null or cb == null:
		return
	var pa := _cell_position(a)
	var pb := _cell_position(b)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ca, "position", pb, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cb, "position", pa, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	ca.set_meta("cell", b)
	cb.set_meta("cell", a)
	ca.name = "Candy_%d_%d" % [b.x, b.y]
	cb.name = "Candy_%d_%d" % [a.x, a.y]

func _find_candy(cell: Vector2i) -> Node3D:
	for child in get_children():
		if child is Node3D and child.has_meta("cell") and child.get_meta("cell") == cell:
			return child
	return null

func _find_matches() -> Dictionary:
	var found := {}
	for y in range(GRID_SIZE):
		var x := 0
		while x < GRID_SIZE:
			var kind = grid[y][x]
			var end := x + 1
			while end < GRID_SIZE and grid[y][end] == kind:
				end += 1
			if end - x >= 3:
				for k in range(x, end):
					found[Vector2i(k, y)] = true
			x = end
	for x in range(GRID_SIZE):
		var y := 0
		while y < GRID_SIZE:
			var kind = grid[y][x]
			var end := y + 1
			while end < GRID_SIZE and grid[end][x] == kind:
				end += 1
			if end - y >= 3:
				for k in range(y, end):
					found[Vector2i(x, k)] = true
			y = end
	return found

func _resolve_matches(matches: Dictionary) -> void:
	while not matches.is_empty():
		score += matches.size() * 60
		for cell in matches.keys():
			var candy := _find_candy(cell)
			if candy != null:
				var tween := create_tween()
				tween.tween_property(candy, "scale", Vector3.ZERO, 0.13)
				await tween.finished
				candy.queue_free()
			grid[cell.y][cell.x] = -1
		await get_tree().create_timer(0.08).timeout
		for x in range(GRID_SIZE):
			var write_y := GRID_SIZE - 1
			for y in range(GRID_SIZE - 1, -1, -1):
				if grid[y][x] != -1:
					if write_y != y:
						var kind = grid[y][x]
						grid[write_y][x] = kind
						grid[y][x] = -1
						var candy := _find_candy(Vector2i(x, y))
						if candy != null:
							candy.set_meta("cell", Vector2i(x, write_y))
							candy.name = "Candy_%d_%d" % [x, write_y]
							var fall := create_tween()
							fall.tween_property(candy, "position", _cell_position(Vector2i(x, write_y)), 0.18)
					write_y -= 1
			for y in range(write_y, -1, -1):
				var kind := randi_range(0, CANDY_TYPES - 1)
				grid[y][x] = kind
				_create_candy(Vector2i(x, y), kind)
		await get_tree().create_timer(0.22).timeout
		matches = _find_matches()
		_update_hud()
	hint_label.text = "Nice! Keep matching candies"

func _update_hud() -> void:
	moves_label.text = "MOVES  %d" % moves
	score_label.text = "SCORE  %d" % score
