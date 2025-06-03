extends Node

enum Turn { PLAYER, ENEMY }

var current_turn: Turn = Turn.PLAYER
var grid
var is_player_turn = true
var game_has_ended := false
func _ready():
	grid = get_tree().get_first_node_in_group("grid")

func print_character_stats():
	print("\n--- CHARACTER STATS ---")
	for char in get_tree().get_nodes_in_group("character"):
		if not is_instance_valid(char):
			continue
		var name = char.name
		var faction = char.faction if "faction" in char else "unknown"
		var health = char.health if "health" in char else -1
		var moved = char.has_moved if "has_moved" in char else false
		print("%s (%s) - HP: %d, Has Moved: %s" % [name, faction, health, str(moved)])
	print("--- END STATS ---\n")

func next_turn():
	is_player_turn = !is_player_turn

	for char in get_tree().get_nodes_in_group("character"):
		if is_instance_valid(char):
			char.has_moved = false

	if not is_player_turn:
		print("== ENEMY TURN ==")
		print_character_stats()
		await _enemy_turn()

func _enemy_turn():
	print("Enemy turn started")
	await get_tree().create_timer(1.0).timeout

	var enemies = get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))
	var player_units = get_tree().get_nodes_in_group("character").filter(func(c): return is_instance_valid(c) and c.faction == "player")
	var goblins_to_remove = []

	for goblin in enemies:
		if not is_instance_valid(goblin) or goblin.has_moved:
			continue

		if await _try_attack_adjacent(goblin, player_units):
			player_units = player_units.filter(func(p): return is_instance_valid(p))
			goblin.has_moved = true
			await get_tree().create_timer(0.2).timeout
			if goblin.health <= 0:
				goblins_to_remove.append(goblin)
			continue

		var path = _astar_goblin_move(goblin, player_units)
		if path.size() > 1:
			print("Goblin", goblin.name, "moves to", path[1])
			await goblin.move_to(path)
			goblin.has_moved = true
		else:
			print("Goblin", goblin.name, "has no valid move")

		await get_tree().create_timer(0.2).timeout
		if goblin.health <= 0:
			goblins_to_remove.append(goblin)

	for goblin in goblins_to_remove:
		if is_instance_valid(goblin):
			var sprite = goblin.get_node_or_null("AnimatedSprite2D")
			if sprite and "death" in sprite.sprite_frames.get_animation_names():
				sprite.play("death")
				var frame_count = sprite.sprite_frames.get_frame_count("death")
				var speed = sprite.sprite_frames.get_animation_speed("death")
				var duration = float(frame_count) / max(speed, 1.0)
				await get_tree().create_timer(duration).timeout
			else:
				await get_tree().create_timer(0.5).timeout # fallback

			if is_instance_valid(goblin):
				goblin.queue_free()
	
	#check if game should end after goblin deaths
	check_game_end()

	is_player_turn = true
	for char in get_tree().get_nodes_in_group("character"):
		if is_instance_valid(char):
			char.has_moved = false

	print("== PLAYER TURN ==")
	print_character_stats()

func _astar_goblin_move(goblin, player_units) -> Array:
	if not is_instance_valid(goblin) or player_units.is_empty():
		return []

	var grid_local = get_tree().get_first_node_in_group("grid")
	var start = grid_local._get_grid_position(goblin.global_position)
	var occupied = []

	# Get all occupied tiles except for the goblin itself
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e != goblin:
			occupied.append(grid_local._get_grid_position(e.global_position))
	for p in player_units:
		if is_instance_valid(p):
			occupied.append(grid_local._get_grid_position(p.global_position))

	# List of candidate destinations: cardinal-adjacent to each knight
	var candidate_targets: Array = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

	for player in player_units:
		if not is_instance_valid(player):
			continue
		var p_pos = grid_local._get_grid_position(player.global_position)
		for dir in directions:
			var adj = p_pos + dir
			if adj in occupied:
				continue
			if not grid_local.aStar.is_in_bounds(adj.x, adj.y):
				continue
			if grid_local.aStar.is_point_solid(adj):
				continue
			candidate_targets.append(adj)

	# If no valid cardinal-adjacent tile found, fallback to knight tile
	if candidate_targets.is_empty():
		for player in player_units:
			if is_instance_valid(player):
				candidate_targets.append(grid_local._get_grid_position(player.global_position))

	if candidate_targets.is_empty():
		return []
	
	# Choose the nearest candidate
	var best_target = candidate_targets[0]
	var best_distance = start.distance_to(best_target)
	for target in candidate_targets:
		var d = start.distance_to(target)
		if d < best_distance:
			best_target = target
			best_distance = d

	var path = grid_local.aStar.get_id_path(start, best_target)

	# Filter out blocked positions (except the start)
	var filtered_path = []
	for i in path:
		if i == start or not (i in occupied):
			filtered_path.append(i)

	# Limit movement to 3 tiles (start + 3 steps = 4 total)
	if filtered_path.size() > 4:
		filtered_path = filtered_path.slice(0, 4)

	return filtered_path

func _try_attack_adjacent(attacker, targets: Array) -> bool:
	if not is_instance_valid(attacker):
		return false

	if grid == null:
		grid = get_tree().get_first_node_in_group("grid")

	var attacker_pos = grid._get_grid_position(attacker.global_position)

	for target in targets:
		if not is_instance_valid(target):
			continue

		var target_pos = grid._get_grid_position(target.global_position)
		if attacker_pos.distance_to(target_pos) == 1:
			if attacker.has_node("AnimatedSprite2D"):
				var sprite = attacker.get_node("AnimatedSprite2D")
				if sprite.sprite_frames and "attack" in sprite.sprite_frames.get_animation_names():
					sprite.play("attack")
					var frame_count = sprite.sprite_frames.get_frame_count("attack")
					var speed = sprite.sprite_frames.get_animation_speed("attack")
					var attack_duration = float(frame_count) / max(speed, 1.0)
					await get_tree().create_timer(attack_duration).timeout
					if is_instance_valid(attacker):
						sprite.play("idle")

			if not is_instance_valid(attacker) or not is_instance_valid(target):
				return false
			if not "damage" in attacker:
				attacker.damage = 1
			if not "health" in target:
				target.health = 5

			if is_instance_valid(target):
				target.health -= attacker.damage
				print("%s attacks %s for %d damage. Target HP: %d" % [attacker.name, target.name, attacker.damage, target.health])
				if "update_health_bar" in target:
					target.update_health_bar()
				if target.health <= 0:
					print("%s has died!" % target.name)
					if is_instance_valid(target):
						var sprite = target.get_node_or_null("AnimatedSprite2D")
						if sprite and "death" in sprite.sprite_frames.get_animation_names():
							sprite.play("death")
							var frame_count = sprite.sprite_frames.get_frame_count("death")
							var speed = sprite.sprite_frames.get_animation_speed("death")
							var duration = float(frame_count) / max(speed, 1.0)
							await get_tree().create_timer(duration).timeout
						else:
							await get_tree().create_timer(0.5).timeout # fallback

						if is_instance_valid(target):
							target.queue_free()
							check_game_end()
							return true

			print_character_stats()
			return true

	return false

func player_try_attack(knight):
	var enemies = get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))
	return await _try_attack_adjacent(knight, enemies)

func _get_nearest_knight(grid, goblin, players) -> Vector2i:
	var current = grid._get_grid_position(goblin.global_position)
	var nearest: Vector2i = current
	var nearest_distance := INF

	for player in players:
		if not is_instance_valid(player):
			continue
		var p = grid._get_grid_position(player.global_position)
		var d = current.distance_to(p)
		if d < nearest_distance:
			nearest = p
			nearest_distance = d

	return nearest

func _get_valid_moves_for_player(knight) -> Array:
	var grid_local = get_tree().get_first_node_in_group("grid")
	var start = grid_local._get_grid_position(knight.global_position)
	var valid_moves = []

	var occupied_tiles = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			occupied_tiles.append(grid_local._get_grid_position(e.global_position))
	for player in get_tree().get_nodes_in_group("character"):
		if is_instance_valid(player) and player != knight:
			occupied_tiles.append(grid_local._get_grid_position(player.global_position))

	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dir in directions:
		var pos = start + dir
		if not grid_local.aStar.is_in_bounds(pos.x, pos.y):
			continue
		if grid_local.aStar.is_point_solid(pos):
			continue
		if pos in occupied_tiles:
			continue
		valid_moves.append(pos)

	return valid_moves

func _on_EndTurnButton_pressed():
	if is_player_turn:
		await _knight_auto_attack()
		await next_turn()

func on_button_pressed():
	print("End Button pressed!")
	if is_player_turn:
		await _knight_auto_attack()
		await next_turn()

func _knight_auto_attack():
	var knights = get_tree().get_nodes_in_group("character").filter(func(c): return is_instance_valid(c) and c.faction == "player")
	var goblins = get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))

	for knight in knights:
		await _try_attack_adjacent(knight, goblins)
		# Re-filter goblins after each attack to remove any freed ones
		goblins = goblins.filter(func(e): return is_instance_valid(e))
	
	check_game_end()

func check_game_end():
	if game_has_ended:
		return
	var goblins = get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))
	var knights = get_tree().get_nodes_in_group("character").filter(func(k): return is_instance_valid(k) and k.faction == "player")

	if knights.size() == 0:
		print("Game Over: All knights defeated")
		get_tree().change_scene_to_file("res://GameOver.tscn")
	elif goblins.size() == 0:
		print("Victory: All goblins defeated")
		get_tree().change_scene_to_file("res://Victory.tscn")
