extends CharacterBody2D

signal character_selected

@export var movement := 5
@export var faction: String = "player"
@export var health := 6
@export var damage := 3

var max_health := 6  # Used for percentage calculation

var cellSize: Vector2
var has_moved := false

var sprite: AnimatedSprite2D
@onready var health_bar = $HealthBar
@onready var hb = $ProgressBar

func _ready() -> void:
	add_to_group("character")
	await _set_cell_size()
	sprite = $AnimatedSprite2D  # Adjust path if needed
	max_health = health
	sprite.play("idle")
	
	health_bar.min_value=0
	health_bar.max_value=max_health
	health_bar.value=max_health
	
	hb.min_value=0
	hb.max_value=max_health
	hb.value=max_health
	
	update_health_bar()
	#await get_tree().create_timer(2.0).timeout
	#take_damage(3)
	#await get_tree().create_timer(1.0).timeout
	#take_damage(1)

func _set_cell_size():
	await get_tree().current_scene.ready
	var grid = get_tree().get_first_node_in_group("grid")
	cellSize = Vector2(grid.cellWidth + grid.borderSize, grid.cellHeight + grid.borderSize)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	var onLeftClicked :bool = event is InputEventMouseButton and event.button_index == 1 and event.is_pressed()
	if onLeftClicked: 
		character_selected.emit(movement)

func move_to(positionSequence: Array):
	if positionSequence.size() < 2:
		print("Invalid path: Not enough points to move.")
		return

	var startPosition = positionSequence[0]
	sprite.play("moving")

	for movePosition in positionSequence.slice(1, positionSequence.size()):
		var direction = movePosition - startPosition
		
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
