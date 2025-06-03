extends CharacterBody2D

signal character_selected

@export var movement := 3
@export var faction: String = "enemy"
@export var health := 4
@export var damage := 2

var max_health := 4
var cellSize: Vector2
var has_moved := false
var sprite: AnimatedSprite2D

@onready var health_bar = $HealthBar  # Make sure this node exists in the scene
@onready var hb = $ProgressBar

func _ready():
	add_to_group("character")
	add_to_group("enemy")
	await _set_cell_size()
	sprite = $AnimatedSprite2D
	sprite.play("idle")

	max_health = health
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = max_health
	
	hb.min_value=0
	hb.max_value=max_health
	hb.value=max_health
	
	update_health_bar()

func _set_cell_size():
	await get_tree().current_scene.ready
	var grid = get_tree().get_first_node_in_group("grid")
	cellSize = Vector2(grid.cellWidth + grid.borderSize, grid.cellHeight + grid.borderSize)

func move_to(positionSequence: Array):
	if positionSequence.size() == 0:
		return

	var startPosition = positionSequence.pop_front()
	sprite.play("moving")

	for movePosition in positionSequence:
		var direction = movePosition - startPosition

		# Restrict to cardinal movement (in case path includes diagonals)
		if abs(direction.x) + abs(direction.y) != 1:
			continue  # Skip illegal moves

		if direction.x != 0:
			sprite.flip_h = direction.x < 0

		var tween = get_tree().create_tween()
		tween.tween_property(self, "global_position", global_position + Vector2(direction) * cellSize, 0.75)
		await tween.finished
		startPosition = movePosition

	sprite.play("idle")

func take_damage(amount: int):
	print("Taking damage:", amount)
	health = max(health - amount, 0)
	print("Health after damage:", health)
	update_health_bar()
	if health <= 0:
		die()

func update_health_bar():
	print("Before updating: health =", health, "max_health =", max_health)
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = clamp(health, 0, max_health)
	hb.min_value=0
	hb.max_value=max_health
	hb.value=clamp(health,0,max_health)
	print("Health bar value set to:", health_bar.value)


func die():
	queue_free()
