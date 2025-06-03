@tool
extends GridContainer

#enum Difficulty { EASY, HARD }
@export var difficulty: GameSettings.Difficulty 

@export var KnightScene: PackedScene
@export var TreeScene: PackedScene
@export var GoblinScene: PackedScene
@export var goblin_count: int = 3
@export var goblin_vertical_offset: int = 0
@export var tree_count: int = 10  # Or however many trees you want
@export var tree_vertical_offset: int = 0

# Dictionary to track terrain tiles
var solidTiles := {}
var grid_cells := {}

@export var width := 5:
	set(value):
		width = value
		_rebuild_grid()

@export var height := 5:
	set(value):
		height = value
		_rebuild_grid()

@export var cellWidth := 100:
	set(value):
		cellWidth = value
		_rebuild_grid()

@export var cellHeight := 100:
	set(value):
		cellHeight = value
		_rebuild_grid()

const GRID_CELL = preload("res://grid_cell.tscn")
const borderSize = 4

var selectedCharacter: CharacterBody2D
var aStar: AStarGrid2D
var occupiedTiles = {}
var validTiles = []

func _ready() -> void:
	difficulty = GameSettings.current_difficulty 
	aStar = AStarGrid2D.new()
	aStar.region = Rect2i(0, 0, width, height)
	aStar.cell_size = Vector2i(cellWidth + borderSize, cellHeight + borderSize)
	aStar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	aStar.update()

	for x in range(width):
		for y in range(height):
			aStar.set_point_solid(Vector2i(x, y), false)

	add_to_group("grid")
	_add_signals()
	_create_grid()
	spawn_trees(tree_count)
	spawn_knights(3)

	# Use difficulty to decide goblin count
	print("Difficulty:", difficulty, "Expected HARD:", difficulty )

	var goblin_spawn_count = 7 if difficulty == GameSettings.Difficulty.EASY else 9
	spawn_goblins(goblin_spawn_count)

	# Debug
	for char in get_tree().get_nodes_in_group("character"):
		print("CHAR:", char.name, "Parent:", char.get_parent())

func _rebuild_grid():
	if Engine.is_editor_hint():
		_remove_grid()
		_create_grid()

func _create_grid():
	columns = width
	for i in width * height:
		var gridCellNode = GRID_CELL.instantiate()
		gridCellNode.custom_minimum_size = Vector2(cellWidth, cellHeight)
		add_child(gridCellNode)
		
		var x = i % width
		var y = int(i / width)
		grid_cells[Vector2i(x, y)] = gridCellNode

func _remove_grid():
	for node in get_children():
		node.queue_free()

func spawn_knights(count: int) -> void:
	print("Spawning knights...")

	if not KnightScene:
		push_error("KnightScene not assigned in the inspector.")
		return

	var left_columns = int(width / 3)
	var possible_positions := []

	for x in range(left_columns):
		for y in range(height):
			var pos = Vector2i(x, y)
			if not occupiedTiles.has(pos):
				possible_positions.append(pos)

	print("Available positions:", possible_positions)
	possible_positions.shuffle()

	# Apply vertical offset to knights
	var vertical_offset = 40  # Adjust this value for your needs

	for i in range(min(count, possible_positions.size())):
		var grid_pos = possible_positions[i]
		var knight = KnightScene.instantiate()

		# Calculate pixel position in grid
		var pixel_pos = Vector2(
			grid_pos.x * (cellWidth + borderSize) + cellWidth / 2,
			grid_pos.y * (cellHeight + borderSize) + cellHeight / 2
		)

		# Adjust knight's position by adding the vertical offset
		var knight_position = self.global_position + pixel_pos
		knight_position.y += vertical_offset  # Apply vertical offset

		knight.global_position = knight_position

		var player_node = get_tree().get_root().get_node("Game/Units/Player")
		if player_node:
			player_node.add_child(knight)
		else:
			push_error("Units/Player node not found!")

		knight.add_to_group("character")
		occupiedTiles[grid_pos] = knight
		aStar.set_point_solid(grid_pos, true)
		print("Knight spawned at:", grid_pos, "Pixel:", knight.global_position)

func spawn_goblins(count: int) -> void:
	print("Spawning goblins...")

	if not GoblinScene:
		push_error("GoblinScene not assigned in the inspector.")
		return

	var right_columns = int(width * 2 / 3)
	var possible_positions := []

	for x in range(right_columns, width):
		for y in range(height):
			var pos = Vector2i(x, y)
			if not occupiedTiles.has(pos) and not solidTiles.has(pos):
				possible_positions.append(pos)

	possible_positions.shuffle()

	for i in range(min(count, possible_positions.size())):
		var grid_pos = possible_positions[i]
		var goblin = GoblinScene.instantiate()

		var pixel_pos = Vector2(
			grid_pos.x * (cellWidth + borderSize) + cellWidth / 2,
			grid_pos.y * (cellHeight + borderSize) + cellHeight / 2 + goblin_vertical_offset
		)

		goblin.global_position = self.global_position + pixel_pos

		var enemy_node = get_tree().get_root().get_node("Game/Units/Enemy")
		if enemy_node:
			enemy_node.add_child(goblin)
		else:
			push_error("Units/Enemy node not found!")

		goblin.add_to_group("character")
		occupiedTiles[grid_pos] = goblin
		#solidTiles[grid_pos] = goblin
		#aStar.set_point_solid(grid_pos, true)  # ✅ Prevent pathing through goblins

		print("Goblin spawned at:", grid_pos)

func spawn_trees(count: int) -> void:
	print("Spawning trees...")

	if not TreeScene:
		push_error("TreeScene not assigned in the inspector.")
		return

	var possible_positions := []

	for x in range(width):
		for y in range(height):
			var pos = Vector2i(x, y)
			if not occupiedTiles.has(pos) and not solidTiles.has(pos):
				possible_positions.append(pos)

	possible_positions.shuffle()

	for i in range(min(count, possible_positions.size())):
		var grid_pos = possible_positions[i]
		var tree = TreeScene.instantiate()

		var pixel_pos = Vector2(
			grid_pos.x * (cellWidth + borderSize) + cellWidth / 2,
			grid_pos.y * (cellHeight + borderSize) + cellHeight / 2 + tree_vertical_offset  # vertical offset like knights
		)

		tree.global_position = self.global_position + pixel_pos

		var terrain_node = get_tree().get_root().get_node("Game/Units/Terrain")
		if terrain_node:
			terrain_node.add_child(tree)
		else:
			push_error("Units/Terrain node not found!")

		# 💡 Mark tile as occupied and solid for pathfinding
		occupiedTiles[grid_pos] = tree
		solidTiles[grid_pos] = tree
		aStar.set_point_solid(grid_pos, true)  # Block it in pathfinding

		print("Tree spawned at:", grid_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.is_pressed():
		_on_left_click()

func _on_left_click():
	var selectedNode = _get_selected_node()
	if selectedNode and selectedCharacter:
		_move_char(selectedNode)
	else:
		selectedCharacter = null
		_deselect_all()

func _move_char(targetNode):
	var targetGridPos = _get_grid_position(targetNode.get_center_position())

	if targetGridPos not in validTiles:
		print("Invalid move: Not a highlighted tile!")
		return
	if occupiedTiles.has(targetGridPos):
		print("Invalid move: Tile is already occupied!")
		return
	if selectedCharacter:
		if selectedCharacter.has_moved:
			print("Character already moved!")
			return

		var startGridPos = _get_grid_position(selectedCharacter.global_position)

		# Mark ALL other occupied tiles (goblins + other knights) as solid
		for grid_pos in occupiedTiles.keys():
			if grid_pos != startGridPos:
				aStar.set_point_solid(grid_pos, true)
		aStar.set_point_solid(startGridPos, false)  # Make sure selected unit's tile is not solid

		var positionSequence = _get_movement_sequence(targetNode.get_center_position())

		# Restore solid state using solidTiles (for goblins, trees, etc.)
		for x in range(width):
			for y in range(height):
				var pos = Vector2i(x, y)
				var is_solid = solidTiles.has(pos)
				aStar.set_point_solid(pos, is_solid)

		if positionSequence.is_empty():
			print("No valid path found!")
			return

		# Update character position
		occupiedTiles.erase(startGridPos)
		occupiedTiles[targetGridPos] = selectedCharacter
		selectedCharacter.move_to(positionSequence)
		selectedCharacter.has_moved = true

	selectedCharacter = null
	_deselect_all()


func _get_movement_sequence(targetPosition) -> Array:
	var positionSequence = []
	if not selectedCharacter:
		print("No character selected")
		return positionSequence

	var startGridPos = _get_grid_position(selectedCharacter.global_position)
	var endGridPos = _get_grid_position(targetPosition)

	if not aStar.is_in_bounds(startGridPos.x, startGridPos.y) or not aStar.is_in_bounds(endGridPos.x, endGridPos.y):
		print("Invalid path: Out of grid bounds")
		return positionSequence

	return aStar.get_id_path(startGridPos, endGridPos)

func _get_grid_position(position: Vector2) -> Vector2i:
	var local_pos = position - global_position
	var grid_x = int(local_pos.x / (cellWidth + borderSize))
	var grid_y = int(local_pos.y / (cellHeight + borderSize))
	return Vector2i(grid_x, grid_y)

func _add_signals():
	await get_tree().current_scene.ready
	for char in get_tree().get_nodes_in_group("character"):
		char.character_selected.connect(_on_character_selected.bind(char))

func _on_character_selected(movement, char):
	if char.faction == "player" and char.has_moved:
		print("Character has already moved.")
		return

	selectedCharacter = char
	_deselect_all()
	var selectedNode = _get_selected_node()
	if selectedNode:
		selectedNode.highlight_cell()
	_select_possible_movement(movement)

func _deselect_all():
	validTiles.clear()
	for node in get_children():
		node.deselect_cell()

func _get_selected_node():
	for node in get_children():
		if node.get_global_rect().has_point(get_global_mouse_position()):
			return node

func _select_possible_movement(movement):
	var startGridPos = _get_grid_position(selectedCharacter.global_position)
	validTiles.clear()

	# Ensure only the current character's tile is walkable
	for grid_pos in occupiedTiles.keys():
		if grid_pos != startGridPos:
			aStar.set_point_solid(grid_pos, true)
	aStar.set_point_solid(startGridPos, false)

	# Dijkstra-like approach: explore reachable tiles within movement range
	var open := [startGridPos]
	var came_from := {}
	var cost_so_far := {}
	came_from[startGridPos] = null
	cost_so_far[startGridPos] = 0

	while open.size() > 0:
		var current = open.pop_front()
		for dir in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor = current + dir
			if not aStar.is_in_bounds(neighbor.x, neighbor.y):
				continue
			if aStar.is_point_solid(neighbor):
				continue
			var new_cost = cost_so_far[current] + 1
			if new_cost <= movement and (not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]):
				cost_so_far[neighbor] = new_cost
				came_from[neighbor] = current
				open.append(neighbor)

	for tile in cost_so_far.keys():
		if tile != startGridPos:
			validTiles.append(tile)
			var pixelPos = Vector2(
				tile.x * (cellWidth + borderSize) + cellWidth / 2,
				tile.y * (cellHeight + borderSize) + cellHeight / 2
			)
			for node in get_children():
				if node.get_global_rect().has_point(global_position + pixelPos):
					node.select_cell()

func _get_cell(position: Vector2):
	for node in get_children():
		if node.get_global_rect().has_point(position):
			return node
