extends Control

@onready var grid = $Grid
@onready var row_arrows = $RowArrows
@onready var column_arrows = $ColumnArrows

const GRID_SIZE = 20
const CELL_SIZE = 32
const TOWER_RANGE = 3
const TOWER_DAMAGE = 25
const ENEMY_HP = 100
const ENEMY_SPEED = 1.0  # tiles per second

var grid_data = []
var cell_buttons = []
var enemies = []
var towers = []
var spawn_point = Vector2i(0, 0)
var exit_point = Vector2i(19, 19)

# Grid cell types
enum CellType {
	EMPTY = 0,
	TOWER = 1,
	TERRAIN = 2,
	WALL = 3
}

# Enemy class with visual representation
class Enemy:
	var grid_position: Vector2i
	var world_position: Vector2
	var target_world_position: Vector2
	var hp: int
	var max_hp: int
	var path: Array[Vector2i]
	var path_index: int
	var hp_label: Label
	var visual: ColorRect
	var is_moving: bool = false
	var move_progress: float = 0.0
	
	func _init(pos: Vector2i, max_health: int):
		grid_position = pos
		hp = max_health
		max_hp = max_health
		path = []
		path_index = 0

# Tower class
class Tower:
	var position: Vector2i
	var last_shot_time: float
	var shoot_cooldown: float = 1.0
	
	func _init(pos: Vector2i):
		position = pos
		last_shot_time = 0

func _ready():
	setup_grid()
	setup_arrows()
	setup_ui_instructions()
	generate_terrain()
	generate_random_spawn_exit()
	start_enemy_spawning()

func setup_ui_instructions():
	var instructions = Label.new()
	instructions.text = "Controls:\n• Click empty (white) cells to place towers\n• Click terrain (▓) to build walls\n• Click towers/walls to remove them"
	instructions.position = Vector2(50 + GRID_SIZE * CELL_SIZE + 50, 50)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	add_child(instructions)

func setup_grid():
	grid.columns = GRID_SIZE
	grid.position = Vector2(50, 50)
	
	grid_data = []
	for i in range(GRID_SIZE):
		var row = []
		for j in range(GRID_SIZE):
			row.append(CellType.EMPTY)
		grid_data.append(row)
	
	cell_buttons = []
	for i in range(GRID_SIZE):
		var row = []
		for j in range(GRID_SIZE):
			var button = Button.new()
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.text = ""
			button.pressed.connect(_on_cell_clicked.bind(i, j))
			grid.add_child(button)
			row.append(button)
		cell_buttons.append(row)

func generate_terrain():
	# Generate some terrain patterns
	generate_random_terrain_patches()
	generate_terrain_walls()

func generate_random_terrain_patches():
	# Create random terrain patches (like forests or rocks)
	var num_patches = randi_range(3, 6)
	
	for patch in range(num_patches):
		var center_x = randi_range(2, GRID_SIZE - 3)
		var center_y = randi_range(2, GRID_SIZE - 3)
		var patch_size = randi_range(2, 4)
		
		for i in range(-patch_size/2, patch_size/2 + 1):
			for j in range(-patch_size/2, patch_size/2 + 1):
				var x = center_x + i
				var y = center_y + j
				
				if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
					# Random chance to place terrain in patch area
					if randf() < 0.6:
						grid_data[y][x] = CellType.TERRAIN

func generate_terrain_walls():
	# Create some linear terrain features (like walls or rivers)
	var num_walls = randi_range(1, 3)
	
	for wall in range(num_walls):
		if randf() < 0.5:
			# Horizontal wall
			var y = randi_range(3, GRID_SIZE - 4)
			var start_x = randi_range(2, 8)
			var length = randi_range(4, 8)
			
			for x in range(start_x, min(start_x + length, GRID_SIZE - 2)):
				grid_data[y][x] = CellType.TERRAIN
		else:
			# Vertical wall
			var x = randi_range(3, GRID_SIZE - 4)
			var start_y = randi_range(2, 8)
			var length = randi_range(4, 8)
			
			for y in range(start_y, min(start_y + length, GRID_SIZE - 2)):
				grid_data[y][x] = CellType.TERRAIN

func setup_arrows():
	row_arrows.position = Vector2(10, 50)
	for i in range(GRID_SIZE):
		var left_arrow = Button.new()
		left_arrow.text = "←"
		left_arrow.custom_minimum_size = Vector2(30, CELL_SIZE)
		left_arrow.pressed.connect(_on_row_scroll.bind(i, -1))
		row_arrows.add_child(left_arrow)
	
	var right_arrows = VBoxContainer.new()
	right_arrows.position = Vector2(50 + GRID_SIZE * CELL_SIZE + 10, 50)
	add_child(right_arrows)
	
	for i in range(GRID_SIZE):
		var right_arrow = Button.new()
		right_arrow.text = "→"
		right_arrow.custom_minimum_size = Vector2(30, CELL_SIZE)
		right_arrow.pressed.connect(_on_row_scroll.bind(i, 1))
		right_arrows.add_child(right_arrow)
	
	column_arrows.position = Vector2(50, 10)
	for i in range(GRID_SIZE):
		var up_arrow = Button.new()
		up_arrow.text = "↑"
		up_arrow.custom_minimum_size = Vector2(CELL_SIZE, 30)
		up_arrow.pressed.connect(_on_column_scroll.bind(i, -1))
		column_arrows.add_child(up_arrow)
	
	var bottom_arrows = HBoxContainer.new()
	bottom_arrows.position = Vector2(50, 50 + GRID_SIZE * CELL_SIZE + 10)
	add_child(bottom_arrows)
	
	for i in range(GRID_SIZE):
		var down_arrow = Button.new()
		down_arrow.text = "↓"
		down_arrow.custom_minimum_size = Vector2(CELL_SIZE, 30)
		down_arrow.pressed.connect(_on_column_scroll.bind(i, 1))
		bottom_arrows.add_child(down_arrow)

func generate_random_spawn_exit():
	var attempts = 0
	var max_attempts = 20
	
	while attempts < max_attempts:
		# Generate spawn point on random edge
		var edge1 = randi() % 4
		match edge1:
			0: spawn_point = Vector2i(0, randi() % GRID_SIZE)  # Left edge
			1: spawn_point = Vector2i(GRID_SIZE-1, randi() % GRID_SIZE)  # Right edge
			2: spawn_point = Vector2i(randi() % GRID_SIZE, 0)  # Top edge
			3: spawn_point = Vector2i(randi() % GRID_SIZE, GRID_SIZE-1)  # Bottom edge
		
		# Generate exit point on random edge (can be same edge)
		var edge2 = randi() % 4
		match edge2:
			0: exit_point = Vector2i(0, randi() % GRID_SIZE)
			1: exit_point = Vector2i(GRID_SIZE-1, randi() % GRID_SIZE)
			2: exit_point = Vector2i(randi() % GRID_SIZE, 0)
			3: exit_point = Vector2i(randi() % GRID_SIZE, GRID_SIZE-1)
		
		# Ensure spawn and exit aren't the same
		if exit_point == spawn_point:
			attempts += 1
			continue
		
		# Clear spawn and exit points of terrain
		grid_data[spawn_point.y][spawn_point.x] = CellType.EMPTY
		grid_data[exit_point.y][exit_point.x] = CellType.EMPTY
		
		# Test if a path exists
		var test_path = find_path_astar(spawn_point, exit_point)
		if len(test_path) > 0:
			print("Spawn: ", spawn_point, " Exit: ", exit_point)
			return
		
		attempts += 1
	
	# Fallback: clear a simple path if no valid spawn/exit found
	print("No valid spawn/exit found, creating fallback path")
	spawn_point = Vector2i(0, GRID_SIZE/2)
	exit_point = Vector2i(GRID_SIZE-1, GRID_SIZE/2)
	
	# Clear horizontal path
	for x in range(GRID_SIZE):
		grid_data[GRID_SIZE/2][x] = CellType.EMPTY

func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE:
		return false
	
	var cell_type = grid_data[pos.y][pos.x]
	return cell_type == CellType.EMPTY or pos == spawn_point or pos == exit_point

func find_path_astar(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: heuristic(start, end)}
	
	while len(open_set) > 0:
		# Find node with lowest f_score
		var current = open_set[0]
		var current_index = 0
		for i in range(len(open_set)):
			if f_score.get(open_set[i], INF) < f_score.get(current, INF):
				current = open_set[i]
				current_index = i
		
		if current == end:
			# Reconstruct path
			var path: Array[Vector2i] = []
			while current in came_from:
				path.push_front(current)
				current = came_from[current]
			path.push_front(start)
			return path
		
		open_set.remove_at(current_index)
		
		# Check neighbors (4-directional)
		var neighbors = [
			current + Vector2i(0, 1),   # down
			current + Vector2i(0, -1),  # up
			current + Vector2i(1, 0),   # right
			current + Vector2i(-1, 0)   # left
		]
		
		for neighbor in neighbors:
			if not is_walkable(neighbor):
				continue
			
			var tentative_g_score = g_score.get(current, INF) + 1
			
			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + heuristic(neighbor, end)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []  # No path found

func heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func start_enemy_spawning():
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(spawn_enemy)
	timer.autostart = true
	add_child(timer)
	
	var shoot_timer = Timer.new()
	shoot_timer.wait_time = 0.1
	shoot_timer.timeout.connect(update_towers)
	shoot_timer.autostart = true
	add_child(shoot_timer)

func spawn_enemy():
	var enemy = Enemy.new(spawn_point, ENEMY_HP)
	enemy.path = find_path_astar(spawn_point, exit_point)
	
	if len(enemy.path) == 0:
		print("No path found for enemy!")
		return
	
	# Create visual enemy (red square)
	enemy.visual = ColorRect.new()
	enemy.visual.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	enemy.visual.color = Color.RED
	enemy.world_position = grid_to_world_pos(enemy.grid_position)
	enemy.target_world_position = enemy.world_position
	enemy.visual.position = enemy.world_position + Vector2(2, 2)
	add_child(enemy.visual)
	
	# Create HP label
	enemy.hp_label = Label.new()
	enemy.hp_label.text = str(enemy.hp)
	enemy.hp_label.add_theme_color_override("font_color", Color.WHITE)
	enemy.hp_label.position = enemy.world_position + Vector2(5, -15)
	add_child(enemy.hp_label)
	
	enemies.append(enemy)
	print("Enemy spawned, path length: ", len(enemy.path))

func grid_to_world_pos(grid_pos: Vector2i) -> Vector2:
	return grid.position + Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)

func update_towers():
	for tower in towers:
		if Time.get_ticks_msec() / 1000.0 - tower.last_shot_time > tower.shoot_cooldown:
			shoot_from_tower(tower)

func shoot_from_tower(tower: Tower):
	var closest_enemy = null
	var closest_distance = TOWER_RANGE + 1
	
	for enemy in enemies:
		var distance = abs(enemy.grid_position.x - tower.position.x) + abs(enemy.grid_position.y - tower.position.y)
		if distance <= TOWER_RANGE and distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance
	
	if closest_enemy:
		closest_enemy.hp -= TOWER_DAMAGE
		tower.last_shot_time = Time.get_ticks_msec() / 1000.0
		
		if closest_enemy.hp <= 0:
			remove_enemy(closest_enemy)
		else:
			closest_enemy.hp_label.text = str(closest_enemy.hp)

func remove_enemy(enemy: Enemy):
	if enemy.hp_label:
		enemy.hp_label.queue_free()
	if enemy.visual:
		enemy.visual.queue_free()
	enemies.erase(enemy)

func _process(delta):
	# Move enemies along their paths
	for enemy in enemies:
		if enemy.path_index < len(enemy.path) - 1:
			if not enemy.is_moving:
				# Start moving to next tile
				enemy.is_moving = true
				enemy.move_progress = 0.0
				enemy.target_world_position = grid_to_world_pos(enemy.path[enemy.path_index + 1])
			
			# Update movement progress
			enemy.move_progress += delta * ENEMY_SPEED
			
			if enemy.move_progress >= 1.0:
				# Reached next tile
				enemy.path_index += 1
				enemy.grid_position = enemy.path[enemy.path_index]
				enemy.world_position = enemy.target_world_position
				enemy.is_moving = false
				enemy.move_progress = 0.0
				
				# Check if reached exit
				if enemy.path_index >= len(enemy.path) - 1:
					print("Enemy reached exit!")
					remove_enemy(enemy)
					continue
			else:
				# Interpolate position
				enemy.world_position = lerp(
					grid_to_world_pos(enemy.path[enemy.path_index]),
					enemy.target_world_position,
					enemy.move_progress
				)
		
		# Update visual positions
		if enemy.visual:
			enemy.visual.position = enemy.world_position + Vector2(2, 2)
		if enemy.hp_label:
			enemy.hp_label.position = enemy.world_position + Vector2(5, -15)

func _on_row_scroll(row_index: int, direction: int):
	var row = grid_data[row_index]
	if direction == 1:
		var last = row.pop_back()
		row.push_front(last)
	else:
		var first = row.pop_front()
		row.push_back(first)
	
	for tower in towers:
		if tower.position.y == row_index:
			tower.position.x = (tower.position.x + direction) % GRID_SIZE
			if tower.position.x < 0:
				tower.position.x = GRID_SIZE - 1
	
	update_display()

func _on_column_scroll(col_index: int, direction: int):
	if direction == 1:
		var bottom = grid_data[GRID_SIZE - 1][col_index]
		for i in range(GRID_SIZE - 1, 0, -1):
			grid_data[i][col_index] = grid_data[i - 1][col_index]
		grid_data[0][col_index] = bottom
	else:
		var top = grid_data[0][col_index]
		for i in range(GRID_SIZE - 1):
			grid_data[i][col_index] = grid_data[i + 1][col_index]
		grid_data[GRID_SIZE - 1][col_index] = top
	
	for tower in towers:
		if tower.position.x == col_index:
			tower.position.y = (tower.position.y + direction) % GRID_SIZE
			if tower.position.y < 0:
				tower.position.y = GRID_SIZE - 1
	
	update_display()

func _on_cell_clicked(row: int, col: int):
	var pos = Vector2i(col, row)
	if pos == spawn_point or pos == exit_point:
		return
	
	var current_cell = grid_data[row][col]
	
	match current_cell:
		CellType.EMPTY:
			# Place tower on empty cell
			grid_data[row][col] = CellType.TOWER
			var tower = Tower.new(Vector2i(col, row))
			towers.append(tower)
			print("Tower placed at: ", row, ", ", col)
			recalculate_enemy_paths()
		
		CellType.TERRAIN:
			# Build wall on terrain
			grid_data[row][col] = CellType.WALL
			print("Wall built on terrain at: ", row, ", ", col)
			recalculate_enemy_paths()
		
		CellType.TOWER:
			# Remove tower (optional - allows tower removal)
			grid_data[row][col] = CellType.EMPTY
			# Remove tower from towers array
			for i in range(len(towers)):
				if towers[i].position == Vector2i(col, row):
					towers.remove_at(i)
					break
			print("Tower removed from: ", row, ", ", col)
			recalculate_enemy_paths()
		
		CellType.WALL:
			# Remove wall, revert to terrain
			grid_data[row][col] = CellType.TERRAIN
			print("Wall removed, reverted to terrain at: ", row, ", ", col)
			recalculate_enemy_paths()
	
	update_display()

func recalculate_enemy_paths():
	for enemy in enemies:
		var new_path = find_path_astar(enemy.grid_position, exit_point)
		if len(new_path) > 0:
			enemy.path = new_path
			enemy.path_index = 0
			enemy.is_moving = false
			enemy.move_progress = 0.0
		else:
			print("Enemy trapped! No path available.")
			# Could remove enemy or implement different behavior

func update_display():
	for i in range(GRID_SIZE):
		for j in range(GRID_SIZE):
			var button = cell_buttons[i][j]
			var pos = Vector2i(j, i)
			
			if pos == spawn_point:
				button.modulate = Color.GREEN
				button.text = "S"
			elif pos == exit_point:
				button.modulate = Color.ORANGE
				button.text = "E"
			else:
				match grid_data[i][j]:
					CellType.EMPTY:
						button.modulate = Color.WHITE
						button.text = ""
					CellType.TOWER:
						button.modulate = Color.BLUE
						button.text = "T"
					CellType.TERRAIN:
						button.modulate = Color.DARK_GRAY
						button.text = "▓"
					CellType.WALL:
						button.modulate = Color.BLACK
						button.text = "█"
